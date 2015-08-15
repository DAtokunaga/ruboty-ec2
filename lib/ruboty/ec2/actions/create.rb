module Ruboty
  module Ec2
    module Actions
      class Create < Ruboty::Actions::Base
        def call
          message.reply(create)
        end

        private

        def create
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          r53  = Ruboty::Ec2::Helpers::Route53.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          ami_id   = message[:ami_id]
          caller   = util.get_caller

          # 入力チェック
          if !ins_name.match(/^[a-z0-9\-]+$/) or ins_name.length > 15
            warn_msg =  "インスタンス名は↓このルールで指定してね\n"
            warn_msg << "```\n"
            warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
            warn_msg << "  文字列長 -> 15文字以内\n"
            warn_msg << "```"
            raise warn_msg
          end

          ## 現在利用中のインスタンス／AMIの情報を取得
          ins_infos = ec2.get_ins_infos
          ami_infos = ec2.get_ami_infos

          ## 使用するAMI IDを取得し存在チェック
          if ami_id.nil?
            ami_id = util.get_default_ami
          end
          exist_flg = false
          ami_name      = nil
          ami_infos.each do |name, ami|
            if ami[:image_id] == ami_id
              exist_flg = true
              ami_name  = name
            end
          end
          raise "AMI ID[#{ami_id}]が間違っているよ" if !exist_flg

          ## インスタンス名重複チェック
          ins_infos.each do |name, ins|
            next if ins[:state] == "terminated"
            raise "インスタンス名[#{name}]がかぶってるよー" if ins_name == name
          end

          # 使用するIPアドレスを取得
          subnet_id = util.get_subnet_id
          ipaddr_range = util.usable_iprange(ec2.get_subnet_cidr(subnet_id))
          ipaddr_used  = []
          ami_infos.each do |name, ami|
            ipaddr_used << ami[:ip_addr] if !ami[:ip_addr].nil?
          end
          ins_infos.each do |name, ins|
            ipaddr_used << ins[:private_ip] if !ins[:private_ip].nil? and ins[:subnet_id] == subnet_id
          end
          # 使用可能なIPをランダムに払い出す
          private_ip = (ipaddr_range - ipaddr_used).sample

          # インスタンス作成
          params = {:image_id => ami_id, :private_ip_address => private_ip}
          ins_id = ec2.create_ins(params)
          # タグ付け
          params =  {"Name"  => ins_name, "Owner" => caller, "LastUsedTime" => Time.now.to_s}
          params["Spec"]  = ami_infos[ami_name][:spec]  if !ami_infos[ami_name][:spec].nil?
          params["Desc"]  = ami_infos[ami_name][:desc]  if !ami_infos[ami_name][:desc].nil?
          params["Param"] = ami_infos[ami_name][:param] if !ami_infos[ami_name][:param].nil?
          ec2.update_tags(ins_id, params)

          # メッセージ置換・整形＆インスタンス作成した旨応答
          message.reply("インスタンス[#{ins_name}]を作成したよ. DNS設定完了までもう少し待っててね")

          # パブリックIPを取得
          public_ip = ec2.wait_for_associate_public_ip(ins_id, ins_name)

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
