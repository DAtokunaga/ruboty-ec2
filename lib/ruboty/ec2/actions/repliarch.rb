module Ruboty
  module Ec2
    module Actions
      class Repliarch < Ruboty::Actions::Base
        def call
          puts "ec2 repliarch #{message[:from_multiarc]} #{message[:to_multiins]} called"
          repliarch
        end

        private

        def repliarch
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          fr_multiarc = message[:from_multiarc]
          to_multiins = message[:to_multiins]
          caller      = util.get_caller

          ## 事前チェック ##

          # インスタンス名チェック
          fr_arc_array = fr_multiarc.split(',')
          to_ins_array = to_multiins.split(',')
          raise "コピー元とコピー先のインスタンス数が合わないよ" if fr_arc_array.size != to_ins_array.size
          to_ins_array.each do |ins_name|
            if !ins_name.match(/^[a-z0-9\-]+$/) or ins_name.length > 15 or ins_name.match(/#{Ruboty::Ec2::Const::AdminSuffix4RegExp}$/)
              warn_msg =  "インスタンス名は↓このルールで指定してね\n"
              warn_msg << "```\n"
              warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
              warn_msg << "  文字列長 -> 15文字以内"
              warn_msg << "  最後が'#{Ruboty::Ec2::Const::AdminSuffix}'で終わっていないこと"
              warn_msg << "```"
              raise warn_msg
            end
          end
          # コピー元とコピー先で同名チェック
          fr_arc_array.each do |fr_arc_name|
            raise "コピー元とコピー先で同じインスタンス名が指定されてるよ" if to_ins_array.include?(fr_arc_name)
          end

          ## 現在利用中のインスタンス／AMIの情報を取得
          ins_infos = ec2.get_ins_infos
          arc_infos = ec2.get_arc_infos

          # コピー元チェック
          fr_arc_array.each do |fr_arc_name|
            if arc_infos[fr_arc_name].nil?
              raise "コピー元アーカイブ[#{fr_arc_name}]が見つからないよ"
            end
          end
          # コピー先チェック
          to_ins_array.each do |to_ins_name|
            if !arc_infos[to_ins_name].nil?
              raise "コピー先インスタンス[#{to_ins_name}]と同じ名前のアーカイブが既にあるよ"
            end
            if !ins_infos[to_ins_name].nil?
              raise "コピー先インスタンス[#{to_ins_name}]は既にあるよ"
            end
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

          # アーカイブからインスタンス作成
          fr_arc_array.each_with_index do |fr_arc_name, idx|
            to_ins_name = to_ins_array[idx]

            # 使用可能なIPをランダムに払い出す
            private_ip   = (ipaddr_range - ipaddr_used).sample
            ipaddr_used << private_ip

            # 作成するインスタンスタイプ判定（HVM or PVにより変わります）
            ins_type = (arc_infos[fr_arc_name][:virtual_type] == "hvm" ?
                        Ruboty::Ec2::Const::InsTypeHVM :
                        Ruboty::Ec2::Const::InsTypePV)

            # インスタンス作成
            arc_info = ec2.get_arc_infos({'Name' => fr_arc_name})[fr_arc_name]
            params   = {:image_id           => arc_info[:image_id],
                        :private_ip_address => private_ip,
                        :instance_type      => ins_type}
            ins_id   = ec2.create_ins(params)
            # タグ付け
            params =  {"Name"         => to_ins_name, "Owner" => caller,
                       "LastUsedTime" => Time.now.to_s,
                       "ParentId"     => arc_info[:parent_id]}
            params["Spec"]  = arc_info[:spec]  if !arc_info[:spec].nil?
            params["Desc"]  = arc_info[:desc]  if !arc_info[:desc].nil?
            params["Version"]    = arc_info[:version] if !arc_info[:version].nil?
            # インスタンスのTag[Param]にorchestrationをセット
            params["Param"] = "orchestration"
            # インスタンスにTag[ReplicaInfo]を追加
            params["ReplicaInfo"] = "#{fr_arc_array.join(',')}:#{to_ins_array.join(',')}"
            ec2.update_tags([ins_id], params)
            message.reply("インスタンス[#{to_ins_name}]を作成したよ")
          end

          # メッセージ置換・整形＆インスタンス作成した旨応答
          reply_msg  = "#{fr_arc_array}環境のレプリカを作ってインスタンス#{to_ins_array}を起動したよ.\n"
          reply_msg << "DNS設定完了までもう少し待っててね"
          message.reply(reply_msg)

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_multi_public_ip(to_ins_array)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          message.reply("DNS設定が完了したよ.")
          message.reply("サーバ間の設定調整(15分程度)後に利用できるようになるよ")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
