module Ruboty
  module Ec2
    module Actions
      class Replicate < Ruboty::Actions::Base
        def call
          puts "ec2 replicate #{message[:from_multiins]} #{message[:to_multiins]} called"
          replicate
        end

        private

        def replicate 
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          fr_multiins = message[:from_multiins]
          to_multiins = message[:to_multiins]
          caller   = util.get_caller

          ## 事前チェック ##

          # インスタンス名チェック
          fr_ins_array = fr_multiins.split(',')
          to_ins_array = to_multiins.split(',')
          raise "コピー元とコピー先のインスタンス数が合わないよ" if fr_ins_array.size != to_ins_array.size
          to_ins_array.each do |ins_name|
            if !ins_name.match(/^[a-z0-9\-]+$/) or ins_name.length > 15
              warn_msg =  "インスタンス名は↓このルールで指定してね\n"
              warn_msg << "```\n"
              warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
              warn_msg << "  文字列長 -> 15文字以内"
              warn_msg << "```"
              raise warn_msg
            end
          end
          # コピー元とコピー先で同名チェック
          fr_ins_array.each do |fr_ins_name|
            raise "コピー元とコピー先で同じインスタンス名が指定されてるよ" if to_ins_array.include?(fr_ins_name)
          end

          ## 現在利用中のインスタンス／AMIの情報を取得
          ins_infos = ec2.get_ins_infos
          arc_infos = ec2.get_arc_infos

          # コピー元チェック
          fr_ins_array.each do |fr_ins_name|
            if ins_infos[fr_ins_name].nil?
              raise "コピー元インスタンス[#{fr_ins_name}]が見つからないよ"
            end
          end
          # コピー先チェック
          to_ins_array.each do |to_ins_name|
            if !arc_infos[to_ins_name].nil?
              raise "コピー先インスタンス[#{to_ins_name}]と同じ名前のアーカイブが既にあるよ"
            end
          end
          to_ins_array.each do |to_ins_name|
            if !ins_infos[to_ins_name].nil?
              owner = ins_infos[to_ins_name][:owner]
              # if caller != owner
              # 2017-07-18 知話輪対応
              if util.get_cww_id(caller) != util.get_cww_id(owner)
                raise "インスタンス[#{to_ins_name}]を削除できるのはオーナー[#{owner}]だけだよ"
              end
              # 稼働時間を記録
              ins_info       = ins_infos[to_ins_name]
              last_used_time = ins_info[:last_used_time]
              if !last_used_time.nil? and !last_used_time.empty?
                brain = Ruboty::Ec2::Helpers::Brain.new(message)
                # LastUsedTimeから現在までの課金対象時間を算出
                uptime = util.get_time_diff(last_used_time)
                # Redis上の月別稼働時間累積値を更新
                brain.save_ins_uptime(to_ins_name, uptime)
                # Redis上にins_type,os_typeを保存(インスタンス別料金算出で利用)
                brain.save_ins_type(to_ins_name, ins_info[:instance_type])
                os_type = (!ins_info[:spec].nil? and ins_info[:spec].downcase.include?("rhel")) ? "rhel" : "centos"
                brain.save_os_type(to_ins_name, os_type)
              end
              ec2.destroy_ins(ins_info[:instance_id])
              message.reply("インスタンス[#{to_ins_name}]を強制削除したよ")
            end
          end

          ## メイン処理 ##

          # オンラインでアーカイブ作成
          fr_ins_array.each do |fr_ins_name|
            tmp_ins_info = ins_infos[fr_ins_name]
            ins_id       = tmp_ins_info[:instance_id]
            ami_id       = ec2.create_ami(ins_id, fr_ins_name)

            # タグ付け
            params = {
              "Name"     => fr_ins_name,
              "Owner"    => tmp_ins_info[:owner],
              "ParentId" => tmp_ins_info[:parent_id],
              "IpAddr"   => tmp_ins_info[:private_ip],
              "Spec"     => tmp_ins_info[:spec],
              "Desc"     => tmp_ins_info[:desc]
            }
            params["Param"]      = tmp_ins_info[:param] if !tmp_ins_info[:param].nil?
            #params["AutoStart"]  = tmp_ins_info[:auto_start] if !tmp_ins_info[:auto_start].nil?
            #params["ExceptStop"] = tmp_ins_info[:except_stop] if !tmp_ins_info[:except_stop].nil?
            ec2.update_tags([ami_id], params)
          end

          # アーカイブ作成完了を待機
          message.reply("アーカイブ#{fr_ins_array}を作成中だよ")
          fr_arc_hash = ec2.wait_for_create_multi_ami(fr_ins_array)
          message.reply("アーカイブ#{fr_ins_array}の作成が終わったよ")

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
          fr_ins_array.each_with_index do |fr_ins_name, idx|
            to_ins_name = to_ins_array[idx]

            # 使用可能なIPをランダムに払い出す
            private_ip   = (ipaddr_range - ipaddr_used).sample
            ipaddr_used << private_ip

            # 作成するインスタンスタイプ取得（コピー元から引き継ぐ）
            ins_type = ins_infos[fr_ins_name][:instance_type]

            # インスタンス作成
            arc_info = ec2.get_arc_infos({'Name' => fr_ins_name})[fr_ins_name]
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
            # インスタンスのTag[Param]にorchestrationをセット
            params["Param"] = "orchestration"
            # インスタンスにTag[ReplicaInfo]を追加
            params["ReplicaInfo"] = "#{fr_ins_array.join(',')}:#{to_ins_array.join(',')}"
            ec2.update_tags([ins_id], params)
            message.reply("インスタンス[#{to_ins_name}]を作成したよ")
          end

          # メッセージ置換・整形＆インスタンス作成した旨応答
          reply_msg  = "#{fr_ins_array}環境のレプリカを作ってインスタンス#{to_ins_array}を起動したよ.\n"
          reply_msg << "DNS設定完了までもう少し待っててね"
          message.reply(reply_msg)

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_multi_public_ip(to_ins_array)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          message.reply("DNS設定が完了したよ.")

          # アーカイブ削除
          fr_arc_hash.each do |name, arc_info|
            ec2.destroy_ami(arc_info[:image_id], arc_info[:snapshot_id])
          end
          message.reply("アーカイブ#{fr_ins_array}を削除したよ.")
          message.reply("サーバ間の設定調整(15分程度)後に利用できるようになるよ")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
