module Ruboty
  module Ec2
    module Actions
      class Create < Ruboty::Actions::Base
        def call
          puts "Ruboty::Ec2::Actions::Create.call starting..."
          create
          puts "Ruboty::Ec2::Actions::Create.call finished."
        end

        private

        def create
          puts "Ruboty::Ec2::Actions::Create.create called"
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          ami_id   = (message[:ami_id].nil? ? util.get_default_ami : message[:ami_id])
          _caller   = util.get_caller
          puts "Input Parameter:"
          puts "  ins_name[#{message[:ins_name]}]"
          puts "  ami_id  [#{message[:ami_id]}]"
          puts "  caller  [#{_caller}]"

          ## 事前チェック ##

          # インスタンス名チェック
          if !ins_name.match(/^[a-z0-9\-]+$/) or ins_name.length > 15 or ins_name.match(/#{Ruboty::Ec2::Const::AdminSuffix4RegExp}$/)
            warn_msg =  "インスタンス名は↓このルールで指定してね\n"
            warn_msg << "```\n"
            warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
            warn_msg << "  文字列長 -> 15文字以内\n"
            warn_msg << "  最後が'#{Ruboty::Ec2::Const::AdminSuffix}'で終わっていないこと"
            warn_msg << "```"
            raise warn_msg
          end

          ## 現在利用中のインスタンス／AMIの情報を取得
          # 2019SpeedUp filter条件に対象インスタンス名、対象AMI-IDを追加
          ins_infos = ec2.get_ins_infos({'Name' => ins_name})
          arc_infos = ec2.get_arc_infos({'Name' => ins_name})
          ami_infos = ec2.get_ami_infos({'image-id' => ami_id})

          ## 使用するAMI IDを取得し存在チェック
          raise "AMI ID[#{ami_id}]が間違っているよ" if !ami_infos.include?(ami_id)

          ## インスタンス名重複チェック
          raise "インスタンス[#{ins_name}]は既にあるよ" if ins_infos.include?(ins_name)
          raise "インスタンス[#{ins_name}]は既にアーカイブされてるよ" if arc_infos.include?(ins_name)

          ## メイン処理 ##

          # 使用するIPアドレスを取得
          subnet_id    = util.get_subnet_id
          puts "  subnet_id [#{subnet_id}"
          cidr_block   = ec2.get_subnet_cidr(subnet_id)
          puts "  cidr_block[#{cidr_block}"
          ipaddr_range = util.usable_iprange(cidr_block)
          ipaddr_used  = []
          arc_infos.each do |name, arc|
            ipaddr_used << arc[:ip_addr]
          end
          ins_infos.each do |name, ins|
            ipaddr_used << ins[:private_ip] if ins[:subnet_id] == subnet_id
          end
          # 使用可能なIPをランダムに払い出す
          private_ip = (ipaddr_range - ipaddr_used).sample
          puts "  private_ip[#{private_ip}"

          # 作成するインスタンスタイプ判定（HVM or PVにより変わります）
          ins_type = (ami_infos[ami_id][:virtual_type] == "hvm" ?
                      Ruboty::Ec2::Const::InsTypeHVM :
                      Ruboty::Ec2::Const::InsTypePV)
          puts "  ins_type  [#{ins_type}]"

          # インスタンス作成
          params = {:image_id => ami_id, :private_ip_address => private_ip, :instance_type => ins_type}
          puts "  ins create params => #{params}"
          ins_id = ec2.create_ins(params)
          puts "  ins_id[#{ins_id}]"
          # タグ付け
          params =  {"Name"  => ins_name, "Owner" => _caller,
                     "LastUsedTime" => Time.now.to_s, "ParentId" => ami_id}
          params["Spec"]    = ami_infos[ami_id][:spec]    if !ami_infos[ami_id][:spec].nil?
          params["Desc"]    = ami_infos[ami_id][:desc]    if !ami_infos[ami_id][:desc].nil?
          params["Param"]   = ami_infos[ami_id][:param]   if !ami_infos[ami_id][:param].nil?
          params["Version"] = ami_infos[ami_id][:version] if !ami_infos[ami_id][:version].nil?
          puts "  tags params => #{params}"
          ec2.update_tags([ins_id], params)

          # メッセージ置換・整形＆インスタンス作成した旨応答
          message.reply("インスタンス[#{ins_name}]を作成したよ. DNS設定完了までもう少し待っててね")

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
