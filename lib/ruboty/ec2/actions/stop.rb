module Ruboty
  module Ec2
    module Actions
      class Stop < Ruboty::Actions::Base
        def call
          stop
        end

        private

        def stop
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
          # ステータス[起動]チェック
          ins_info = ins_infos[ins_name]
          raise "インスタンス[#{ins_name}]はもう止まってるよ" if ins_info[:state] == "stopped"
          raise "インスタンス[#{ins_name}]は今処理中で止められないっす..." if ins_info[:state] != "running"

          ## メイン処理 ##

          # 停止処理実施
          ins_id = ins_info[:instance_id]
          ec2.stop_ins([ins_id])

          # Route53 レコード削除処理
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.delete_record_sets({ins_name => ins_info[:public_ip]})

          # 稼働時間を記録
          last_used_time = ins_info[:last_used_time]
          if !last_used_time.nil? and !last_used_time.empty?
            brain = Ruboty::Ec2::Helpers::Brain.new(message)
            # LastUsedTimeから現在までの課金対象時間を算出
            uptime = util.get_time_diff(last_used_time)
            # Redis上の月別稼働時間累積値を更新
            brain.save_ins_uptime(ins_name, uptime)
            # Redis上にins_type,os_typeを保存(インスタンス別料金算出で利用)
            brain.save_ins_type(ins_name, ins_info[:instance_type])
            os_type = (!ins_info[:spec].nil? and ins_info[:spec].downcase.include?("rhel") ? "rhel" : "centos")
            brain.save_os_type(ins_name, os_type)
          end

          # タグ[LastUsedTime]を現在時刻で上書き
          params =  {"LastUsedTime" => Time.now.to_s}
          ec2.update_tags([ins_id], params)

          message.reply("インスタンス[#{ins_name}]を停止したよ")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
