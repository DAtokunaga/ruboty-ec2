module Ruboty
  module Ec2
    module Actions
      class Start < Ruboty::Actions::Base
        def call
          message.reply(start)
        end

        private

        def start
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          r53  = Ruboty::Ec2::Helpers::Route53.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          if ins_infos.empty?
            ami_infos = ec2.get_ami_infos(ins_name)
            raise "インスタンス[#{ins_name}]は存在しないよー" if ami_infos.empty?
            raise "インスタンス[#{ins_name}]はアーカイブ済みだよ"
          end

          # ステータス[停止]チェック
          ins_info = ins_infos[ins_name]
          raise "インスタンス[#{ins_name}]は既に起動してるよ" if ins_info[:state] != "stopped"

          # 起動処理実施
          ins_id = ins_info[:instance_id]
          ec2.start_ins(ins_id)

          # タグ付け
          params =  {"LastUsedTime" => Time.now.to_s}
          ec2.update_tags(ins_id, params)

          # メッセージ置換・整形＆インスタンス起動した旨応答
          message.reply("インスタンス[#{ins_name}]を起動したよ. DNS設定完了までもう少し待っててね")

          # パブリックIPを取得
          public_ip = ec2.wait_for_associate_public_ip(ins_name)

          # DNS設定
          r53.update_record_sets(ins_name, public_ip)
          "DNS設定が完了したよ[#{ins_name}.#{util.get_domain} => #{public_ip}]"

        rescue => e
          e.message
        end
      end
    end
  end
end

