module Ruboty
  module Ec2
    module Actions
      class Autostop < Ruboty::Actions::Base
        def call
          cmd_name = message[:cmd]
          exec if cmd_name == "exec"
          list if cmd_name == "list"
          add  if cmd_name == "add"
          del  if cmd_name == "del"
        end

        private

        def exec
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos

          ## メイン処理 ##

          # 停止対象インスタンス取得
          stop_ins_infos = {}
          ins_infos.each do |name, ins|
            next if ins[:state] != "running"
            next if !ins[:except_stop].nil? and !ins[:except_stop].empty?
            stop_ins_infos[name] = ins
          end
          return if stop_ins_infos.empty?

          # 停止前にPublicIP取得
          ins_pip_hash = {}
          stop_ins_infos.each do |name, ins|
            ins_pip_hash[name] = ins[:public_ip] if !ins[:public_ip].nil?
          end

          # インスタンス停止
          stop_ins_ids = []
          stop_ins_infos.each do |name, ins|
            stop_ins_ids << ins[:instance_id]
          end
          ec2.stop_ins(stop_ins_ids)

          # 稼働時間を記録
          brain = Ruboty::Ec2::Helpers::Brain.new(message)
          stop_ins_infos.each do |name, ins|
            last_used_time = ins[:last_used_time]
            next if last_used_time.nil? or last_used_time.empty?
            # LastUsedTimeから現在までの課金対象時間を算出
            uptime = util.get_time_diff(last_used_time)
            # Redis上の月別稼働時間累積値を更新
            brain.save_ins_uptime(name, uptime)
            # Redis上にins_type,os_typeを保存(インスタンス別料金算出で利用)
            brain.save_ins_type(name, ins[:instance_type])
            os_type = (!ins[:spec].nil? and ins[:spec].downcase.include?("rhel") ? "rhel" : "centos")
            brain.save_os_type(name, os_type)
          end

          # タグ付け
          params =  {"LastUsedTime" => Time.now.to_s}
          ec2.update_tags(stop_ins_ids, params)

          reply_msg  = "自動停止対象インスタンス#{stop_ins_infos.keys}を停止したよ."
          message.reply(reply_msg)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.delete_record_sets(ins_pip_hash)
          message.reply("DNS設定を削除したよ")
        rescue => e
          message.reply(e.message)
        end

        def list
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos

          ## メイン処理 ##

          # 停止対象外インスタンス取得
          except_stop_ins_infos = {}
          ins_infos.each do |name, ins|
            next if ins[:except_stop].nil? or ins[:except_stop].empty?
            except_stop_ins_infos[name] = ins
          end

          msg_list  = ""
          except_stop_ins_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2}.each do |name, ins|
            msg_list << sprintf("\n%-15s | %s", name, ins[:except_stop])
          end
          reply_msg = "自動停止対象外のインスタンス一覧だよ\n```#{msg_list}```"
          reply_msg = "自動停止対象外インスタンスはないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def add
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          return if ins_name.nil?
          caller   = util.get_caller

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
          # 既存設定有無チェック
          ins_info = ins_infos[ins_name]
          if !ins_info[:except_stop].nil? and !ins_info[:except_stop].empty?
            raise "インスタンス[#{ins_name}]は既に自動停止対象外だよ"
          end

          ## メイン処理 ##

          # 停止対象外インスタンス設定（タグ付け）
          tag_value = "set at #{util.now} by #{caller}"
          params =  {"ExceptStop" => tag_value}
          ec2.update_tags([ins_info[:instance_id]], params)
          reply_msg = "インスタンス[#{ins_name}]を自動停止しないように設定したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def del
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          return if ins_name.nil?
          caller   = util.get_caller

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
          # 既存設定有無チェック
          ins_info = ins_infos[ins_name]
          if ins_info[:except_stop].nil? or ins_info[:except_stop].empty?
            raise "インスタンス[#{ins_name}]は自動停止対象外じゃないよ"
          end

          ## メイン処理 ##

          # 停止対象インスタンス設定（タグ付け）
          params =  ["ExceptStop"]
          ec2.delete_tags([ins_info[:instance_id]], params)
          reply_msg = "インスタンス[#{ins_name}]を自動停止するように設定したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
