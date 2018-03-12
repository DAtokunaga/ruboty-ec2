module Ruboty
  module Ec2
    module Actions
      class Start < Ruboty::Actions::Base
        def call
          puts "ec2 start called"
          start
        end

        private

        def start
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos({'Name' => ins_name})
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
          # ステータス[停止]チェック
          ins_info = ins_infos[ins_name]
          raise "インスタンス[#{ins_name}]はもう起動してるよ" if ins_info[:state] == "running"
          raise "インスタンス[#{ins_name}]は今起動できないっす..." if ins_info[:state] != "stopped"

          ## メイン処理 ##

          # 起動処理実施
          ins_id = ins_info[:instance_id]
          ec2.start_ins([ins_id])

          # タグ付け
          params =  {"LastUsedTime" => Time.now.to_s}
          ec2.update_tags([ins_id], params)

          # メッセージ置換・整形＆インスタンス起動した旨応答
          message.reply("インスタンス[#{ins_name}]を起動したよ. DNS設定完了までもう少し待っててね")

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_public_ip(ins_name)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          reply_msg =  "DNS設定が完了したよ[#{util.get_protocol(ins_pip_hash[ins_name][:version])}#{ins_name}.#{util.get_domain} => #{ins_pip_hash[ins_name][:public_ip]}]"
          reply_msg << "[管理 #{util.get_protocol(ins_pip_hash[ins_name][:version])}#{ins_name}#{Ruboty::Ec2::Const::AdminSuffix}.#{util.get_domain}]" if !ins_pip_hash[ins_name][:version].empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end

