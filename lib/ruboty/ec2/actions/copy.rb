module Ruboty
  module Ec2
    module Actions
      class Copy < Ruboty::Actions::Base
        def call
          puts "ec2 copy #{message[:from_arc]} #{message[:to_ins]} called"
          to_ins_name = message[:to_ins]
          if to_ins_name.index(":").nil?
            copy
          else
            copy_over_account
          end
        end

        private

        def copy
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          fr_arc_name = message[:from_arc]
          to_ins_name = message[:to_ins]
          caller   = util.get_caller

          ## 事前チェック ##

          # インスタンス名チェック
          if !to_ins_name.match(/^[a-z0-9\-]+$/) or to_ins_name.length > 15 or to_ins_name.match(/#{Ruboty::Ec2::Const::AdminSuffix4RegExp}$/)
            warn_msg =  "インスタンス名は↓このルールで指定してね\n"
            warn_msg << "```\n"
            warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
            warn_msg << "  文字列長 -> 15文字以内"
            warn_msg << "  最後が'#{Ruboty::Ec2::Const::AdminSuffix}'で終わっていないこと"
            warn_msg << "```"
            raise warn_msg
          end

          ## 現在利用中のインスタンス／AMIの情報を取得
          # 2019SpeedUp filter条件に対象インスタンス名を追加
          ins_infos = ec2.get_ins_infos({'Name' => fr_arc_name})
          ins_infos.merge!(ec2.get_ins_infos({'Name' => to_ins_name}))
          arc_infos = ec2.get_arc_infos({'Name' => fr_arc_name})
          arc_infos.merge!(ec2.get_arc_infos({'Name' => to_ins_name}))

          # コピー元チェック
          raise "コピー元インスタンス[#{fr_arc_name}]を先にアーカイブしてね" if !ins_infos[fr_arc_name].nil?
          raise "コピー元アーカイブ[#{fr_arc_name}]が見つからないよ" if arc_infos[fr_arc_name].nil?
          fr_arc_info = arc_infos[fr_arc_name]
          if fr_arc_info[:state] == "pending"
            raise "コピー元アーカイブ[#{fr_arc_name}]は今作成中なので、もう少し待っててね"
          elsif fr_arc_info[:state] != "available"
            raise "コピー元アーカイブ[#{fr_arc_name}]は今使えないっす..."
          end

          # コピー先チェック
          if !ins_infos[to_ins_name].nil? or !arc_infos[to_ins_name].nil?
            raise "コピー先インスタンス[#{to_ins_name}]は既にあるよ"
          end

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
          ins_type = (fr_arc_info[:virtual_type] == "hvm" ?
                      Ruboty::Ec2::Const::InsTypeHVM :
                      Ruboty::Ec2::Const::InsTypePV)

          # インスタンス作成
          params = {:image_id           => fr_arc_info[:image_id],
                    :private_ip_address => private_ip,
                    :instance_type      => ins_type}
          ins_id = ec2.create_ins(params)
          # タグ付け
          params =  {"Name"  => to_ins_name, "Owner" => caller,
                     "LastUsedTime" => Time.now.to_s,
                     "ParentId" => fr_arc_info[:parent_id]}
          params["Spec"]  = fr_arc_info[:spec]  if !fr_arc_info[:spec].nil?
          params["Desc"]  = fr_arc_info[:desc]  if !fr_arc_info[:desc].nil?
          params["Param"] = fr_arc_info[:param] if !fr_arc_info[:param].nil?
          params["Version"] = fr_arc_info[:version] if !fr_arc_info[:version].nil?
          ec2.update_tags([ins_id], params)

          # メッセージ置換・整形＆インスタンス作成した旨応答
          message.reply("インスタンス[#{to_ins_name}]としてコピーしたよ. DNS設定完了までもう少し待っててね")

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_public_ip(to_ins_name)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          reply_msg =  "DNS設定が完了したよ[#{util.get_protocol(ins_pip_hash[to_ins_name][:version])}#{to_ins_name}.#{util.get_domain} => #{ins_pip_hash[to_ins_name][:public_ip]}]"
          reply_msg << "[管理 #{util.get_protocol(ins_pip_hash[to_ins_name][:version])}#{to_ins_name}#{Ruboty::Ec2::Const::AdminSuffix}.#{util.get_domain}]" if !ins_pip_hash[to_ins_name][:version].empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def copy_over_account
          # チャットコマンド情報取得
          fr_arc_name = message[:from_arc]
          to_account  = message[:to_ins].split(":").first
          to_ins_name = message[:to_ins].split(":").last

          # AWSアクセス、その他ユーティリティのインスタンス化
          fr_util = Ruboty::Ec2::Helpers::Util.new(message)
          fr_ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          to_util = Ruboty::Ec2::Helpers::Util.new(message, to_account)
          to_ec2  = Ruboty::Ec2::Helpers::Ec2.new(message, to_account)
          caller  = fr_util.get_caller

          ## 事前チェック ##

          # インスタンス名チェック
          if !to_ins_name.match(/^[a-z0-9\-]+$/) or to_ins_name.length > 15 or to_ins_name.match(/#{Ruboty::Ec2::Const::AdminSuffix4RegExp}$/)
            warn_msg =  "インスタンス名は↓このルールで指定してね\n"
            warn_msg << "```\n"
            warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
            warn_msg << "  文字列長 -> 15文字以内"
            warn_msg << "  最後が'#{Ruboty::Ec2::Const::AdminSuffix}'で終わっていないこと"
            warn_msg << "```"
            raise warn_msg
          end

          # 同じ名前をエラーとする
          raise "同じ名前ではコピーできないよ" if fr_arc_name == to_ins_name

          ## 現在利用中のインスタンス／AMIの情報を取得
          fr_ins_infos = fr_ec2.get_ins_infos({'Name' => fr_arc_name})
          fr_arc_infos = fr_ec2.get_arc_infos({'Name' => fr_arc_name})
          to_ins_infos = to_ec2.get_ins_infos({'Name' => to_ins_name})
          to_arc_infos = to_ec2.get_arc_infos({'Name' => to_ins_name})

          # コピー元チェック
          raise "コピー元インスタンス[#{fr_arc_name}]を先にアーカイブしてね" if !fr_ins_infos[fr_arc_name].nil?
          raise "コピー元アーカイブ[#{fr_arc_name}]が見つからないよ" if fr_arc_infos[fr_arc_name].nil?
          fr_arc_info = fr_arc_infos[fr_arc_name]
          if fr_arc_info[:state] == "pending"
            raise "コピー元アーカイブ[#{fr_arc_name}]は今作成中なので、もう少し待っててね"
          elsif fr_arc_info[:state] != "available"
            raise "コピー元アーカイブ[#{fr_arc_name}]は今使えないっす..."
          end

          # コピー先チェック
          if !to_ins_infos[to_ins_name].nil? or !to_arc_infos[to_ins_name].nil?
            raise "コピー先インスタンス[#{to_ins_name}]は既にあるよ"
          end

          ## メイン処理 ##

          # 使用するAMIのパーミッションをコピー先AWSアカウントに付与する
          fr_ec2.add_permission(fr_arc_info[:image_id], to_util.get_account_id)

          # 使用するIPアドレスを取得
          subnet_id    = to_util.get_subnet_id
          ipaddr_range = to_util.usable_iprange(to_ec2.get_subnet_cidr(subnet_id))
          ipaddr_used  = []
          to_arc_infos.each do |name, arc|
            ipaddr_used << arc[:ip_addr]
          end
          to_ins_infos.each do |name, ins|
            ipaddr_used << ins[:private_ip] if ins[:subnet_id] == subnet_id
          end
          # 使用可能なIPをランダムに払い出す
          private_ip = (ipaddr_range - ipaddr_used).sample

          # 作成するインスタンスタイプ判定（HVM or PVにより変わります）
          ins_type = (fr_arc_info[:virtual_type] == "hvm" ?
                      Ruboty::Ec2::Const::InsTypeHVM :
                      Ruboty::Ec2::Const::InsTypePV)

          # インスタンス作成
          params = {:image_id           => fr_arc_info[:image_id],
                    :private_ip_address => private_ip,
                    :instance_type      => ins_type}
          ins_id = to_ec2.create_ins(params)
          # タグ付け
          params =  {"Name"  => to_ins_name, "Owner" => caller,
                     "LastUsedTime" => Time.now.to_s,
                     "ParentId" => fr_arc_info[:parent_id]}
          params["Spec"]  = fr_arc_info[:spec]  if !fr_arc_info[:spec].nil?
          params["Desc"]  = fr_arc_info[:desc]  if !fr_arc_info[:desc].nil?
          params["Param"] = fr_arc_info[:param] if !fr_arc_info[:param].nil?
          to_ec2.update_tags([ins_id], params)

          # メッセージ置換・整形＆インスタンス作成した旨応答
          message.reply("チャンネル[#{to_account}]へインスタンス[#{to_ins_name}]としてコピーしたよ. DNS設定完了までもう少し待っててね")

          # パブリックIPを取得
          ins_pip_hash = to_ec2.wait_for_associate_public_ip(to_ins_name)

          # 使用済みAMIのパーミッションをコピー先AWSアカウントから剥奪する
          fr_ec2.delete_permission(fr_arc_info[:image_id], to_util.get_account_id)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message, to_account)
          r53.update_record_sets(ins_pip_hash)
          reply_msg =  "DNS設定が完了したよ[#{to_util.get_protocol(ins_pip_hash[to_ins_name][:version])}#{to_ins_name}.#{to_util.get_domain} => #{ins_pip_hash[to_ins_name][:public_ip]}]"
          reply_msg << "[管理 #{to_util.get_protocol(ins_pip_hash[to_ins_name][:version])}#{to_ins_name}#{Ruboty::Ec2::Const::AdminSuffix}.#{to_util.get_domain}]" if !ins_pip_hash[to_ins_name][:version].empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
