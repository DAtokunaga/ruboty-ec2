module Ruboty
  module Ec2
    module Actions
      class Stop < Ruboty::Actions::Base
        def call
          message.reply(stop)
        end

        private

        def stop
          # AWSアクセス、その他ユーティリティのインスタンス化
          #util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          r53  = Ruboty::Ec2::Helpers::Route53.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          #caller   = util.get_caller

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          raise "インスタンス[#{ins_name}]は存在しないよー" if ins_infos.empty?

          # 存在チェック＆ステータス[起動]チェック
          ins_info = ins_infos[ins_name]
          raise "インスタンス[#{ins_name}]は起動してません" if ins_info[:state] != "running"

          # 停止処理実施
          ins_id   = ins_info[:instance_id]
          ec2.stop_ins(ins_id)

          # Route53 レコード削除処理
          r53.delete_record_sets(ins_name, ins_info[:public_ip])

          # 稼働時間を記録
          last_used_time = ins_info[:last_used_time]
          if !last_used_time.nil? and !last_used_time.empty?
            brain = Ruboty::Ec2::Helpers::Brain.new(message)
            # LastUsedTimeから現在までの課金対象時間を算出
            uptime = brain.calc_uptime(last_used_time)
            # Redis上の月別稼働時間累積値を更新
            brain.save_ins_uptime(ins_name, uptime)
          end

          # タグ[LastUsedTime]を現在時刻で上書き
          params =  {"LastUsedTime" => Time.now.to_s}
          ec2.update_tags(ins_id, params)

          "インスタンス[#{ins_name}]を停止したよ"
        rescue => e
          e.message
        end
      end
    end
  end
end
