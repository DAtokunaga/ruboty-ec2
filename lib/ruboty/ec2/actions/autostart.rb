module Ruboty
  module Ec2
    module Actions
      class Autostart < Ruboty::Actions::Base
        def call
          puts "ec2 autostart #{message[:cmd]} called"
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

          # 起動対象インスタンス取得
          start_ins_infos = {}
          ins_infos.each do |name, ins|
            next if ins[:state] != "stopped"
            next if ins[:auto_start].nil? or ins[:auto_start].empty?
            start_ins_infos[name] = ins
          end
          return if start_ins_infos.empty?

          # インスタンス起動
          start_ins_ids = []
          start_ins_infos.each do |name, ins|
            start_ins_ids << ins[:instance_id]
          end
          ec2.start_ins(start_ins_ids)

          # タグ付け
          params =  {"LastUsedTime" => Time.now.to_s}
          ec2.update_tags(start_ins_ids, params)

          reply_msg  = "自動起動対象インスタンス#{start_ins_infos.keys}を起動したよ."
          reply_msg << "DNS設定完了までもう少し待っててね"
          message.reply(reply_msg)

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_multi_public_ip(start_ins_infos.keys)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          message.reply("DNS設定が完了したよ")
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

          # 起動対象インスタンス取得
          start_ins_infos = {}
          ins_infos.each do |name, ins|
            next if ins[:auto_start].nil? or ins[:auto_start].empty?
            start_ins_infos[name] = ins
          end

          msg_list  = ""
          start_ins_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2}.each do |name, ins|
            msg_list << sprintf("\n%-15s | %s", name, ins[:auto_start])
          end
          reply_msg = "自動起動対象のインスタンス一覧だよ\n```#{msg_list}```"
          reply_msg = "自動起動対象インスタンスはないよ" if msg_list.empty?
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
          if !ins_info[:auto_start].nil? and !ins_info[:auto_start].empty?
            raise "インスタンス[#{ins_name}]は既に自動起動対象だよ"
          end

          ## メイン処理 ##

          # 起動対象インスタンス設定（タグ付け）
          tag_value = "set at #{util.now} by #{caller}"
          params =  {"AutoStart" => tag_value}
          ec2.update_tags([ins_info[:instance_id]], params)
          reply_msg = "インスタンス[#{ins_name}]を自動起動するように設定したよ"
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
          if ins_info[:auto_start].nil? or ins_info[:auto_start].empty?
            raise "インスタンス[#{ins_name}]は自動起動対象じゃないよ"
          end

          ## メイン処理 ##

          # 起動対象解除インスタンス設定（タグ付け）
          params =  ["AutoStart"]
          ec2.delete_tags([ins_info[:instance_id]], params)
          reply_msg = "インスタンス[#{ins_name}]を自動起動しないように設定したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
