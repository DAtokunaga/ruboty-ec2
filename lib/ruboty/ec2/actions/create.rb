module Ruboty
  module Ec2
    module Actions
      class Create < Ruboty::Actions::Base
        def call
          puts "ec2 create called"
          create
        end

        private

        def create
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          ami_id   = (message[:ami_id].nil? ? util.get_default_ami : message[:ami_id])
          caller   = util.get_caller

          ## 事前チェック ##

          # インスタンス名チェック
          if !ins_name.match(/^[a-z0-9\-]+$/) or ins_name.length > 15
            warn_msg =  "インスタンス名は↓このルールで指定してね\n"
            warn_msg << "```\n"
            warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
            warn_msg << "  文字列長 -> 15文字以内"
            warn_msg << "```"
            raise warn_msg
          end

          ## 現在利用中のインスタンス／AMIの情報を取得
          ins_infos = ec2.get_ins_infos
          arc_infos = ec2.get_arc_infos
          ami_infos = ec2.get_ami_infos

          ## 使用するAMI IDを取得し存在チェック
          raise "AMI ID[#{ami_id}]が間違っているよ" if !ami_infos.include?(ami_id)

          ## インスタンス名重複チェック
          raise "インスタンス[#{ins_name}]は既にあるよ" if ins_infos.include?(ins_name)
          raise "インスタンス[#{ins_name}]は既にアーカイブされてるよ" if arc_infos.include?(ins_name)

          ## メイン処理 ##

          # 使用するIPアドレスを取得
          subnet_id    = util.get_subnet_id
          ipaddr_range = util.usable_iprange(ec2.get_subnet_cidr(subnet_id))
          ipaddr_used  = []
          arc_infos.each do |name, arc|
            ipaddr_used << arc[:ip_addr]
          end
          ins_infos.each do |name, ins|
            ipaddr_used << ins[:private_ip] if ins[:subnet_id] == subnet_id
          end
          # 使用可能なIPをランダムに払い出す
          private_ip = (ipaddr_range - ipaddr_used).sample

          # 作成するインスタンスタイプ判定（HVM or PVにより変わります）
          ins_type = (ami_infos[ami_id][:virtual_type] == "hvm" ?
                      Ruboty::Ec2::Const::InsTypeHVM :
                      Ruboty::Ec2::Const::InsTypePV)

          # インスタンス作成
          params = {:image_id => ami_id, :private_ip_address => private_ip, :instance_type => ins_type}
          ins_id = ec2.create_ins(params)
          # タグ付け
          params =  {"Name"  => ins_name, "Owner" => caller,
                     "LastUsedTime" => Time.now.to_s, "ParentId" => ami_id}
          params["Spec"]  = ami_infos[ami_id][:spec]  if !ami_infos[ami_id][:spec].nil?
          params["Desc"]  = ami_infos[ami_id][:desc]  if !ami_infos[ami_id][:desc].nil?
          params["Param"] = ami_infos[ami_id][:param] if !ami_infos[ami_id][:param].nil?
          ec2.update_tags([ins_id], params)

          # メッセージ置換・整形＆インスタンス作成した旨応答
          message.reply("インスタンス[#{ins_name}]を作成したよ. DNS設定完了までもう少し待っててね")

          # パブリックIPを取得
          public_ip = ec2.wait_for_associate_public_ip(ins_name)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets({ins_name => public_ip})
          message.reply("DNS設定が完了したよ[#{ins_name}.#{util.get_domain} => #{public_ip}]")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
