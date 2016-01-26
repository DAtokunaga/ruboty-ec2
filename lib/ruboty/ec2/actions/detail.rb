module Ruboty
  module Ec2
    module Actions
      class Detail < Ruboty::Actions::Base
        def call
          puts "ec2 detail called"
          detail
        end

        private

        def detail
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # インスタンス存在チェック
          if ins_infos.empty?
            arc_infos = ec2.get_arc_infos(ins_name)
            # アーカイブ存在チェック
            if arc_infos.empty?
              raise "インスタンス[#{ins_name}]が見つからないよ" if ins_name.index("ami-").nil?
              ami_infos = ec2.get_ami_infos
              # AMI存在チェック
              raise "インスタンス[#{ins_name}]が見つからないよ" if !ami_infos.include?(ins_name)
              detail_ami(ami_infos[ins_name])
              return
            else
              # ステータス[available]チェック
              arc_info  = arc_infos[ins_name]
              raise "アーカイブ[#{ins_name}]は今使えないっす..." if !["pending", "available"].include?(arc_info[:state])
              detail_arc(arc_info)
            end
          else
            detail_ins(ins_infos[ins_name])
          end
        rescue => e
          message.reply(e.message)
        end

        # インスタンスの詳細情報を表示します
        def detail_ins(ins_info)
          domain     = Ruboty::Ec2::Helpers::Util.new(message).get_domain
          ins_name   = ins_info[:name]
          basic_keys = ["name", "state", "owner", "instance_type", "parent_id", "private_ip", "public_ip"]
          added_keys = ["spec", "desc", "param"]
          reply_msg  = "インスタンス[#{ins_name}]の情報だよ\n"
          reply_msg << "■基本情報\n```"
          basic_keys.each do |key|
            next if ins_info[key.to_sym].nil? or ins_info[key.to_sym].empty?
            reply_msg << sprintf("\n%-12s : %s", key.camelcase, ins_info[key.to_sym])
            if key == "state" and !ins_info[:last_used_time].nil?
              start_or_stop = ins_info[key.to_sym] == "running" ? "started" : "stopped"
              reply_msg << sprintf("  (%s at %s)", start_or_stop, ins_info[:last_used_time])
            end
          end
          reply_msg << "\n```\n■付加情報\n```"
          added_keys.each do |key|
            next if ins_info[key.to_sym].nil? or ins_info[key.to_sym].empty?
            # 整形(改行置換、プレースホルダ変換)
            tag_data  = ins_info[key.to_sym]
            tag_data.gsub!("\\n", "\n")
            tag_data.gsub!("¥n", "\n")
            tag_data.gsub!("&&NAME&&", ins_name)
            tag_data.gsub!("&&FQDN&&", "#{ins_name}.#{domain}")
            reply_msg << "\n[#{key.camelcase}]"
            reply_msg << "\n#{tag_data}"
          end
          reply_msg << "```"
          message.reply(reply_msg)
        end

        # アーカイブの詳細情報を表示します
        def detail_arc(arc_info)
          domain     = Ruboty::Ec2::Helpers::Util.new(message).get_domain
          ins_name   = arc_info[:name]
          basic_keys = ["name", "state", "owner", "parent_id", "ip_addr", "ami_name"]
          added_keys = ["spec", "desc", "param"]
          reply_msg  = "アーカイブ[#{ins_name}]の情報だよ\n"
          reply_msg << "■基本情報\n```"
          basic_keys.each do |key|
            next if arc_info[key.to_sym].nil? or arc_info[key.to_sym].empty?
            reply_msg << sprintf("\n%-12s : %s", key.camelcase, arc_info[key.to_sym])
          end
          reply_msg << "\n```\n■付加情報\n```"
          added_keys.each do |key|
            next if arc_info[key.to_sym].nil? or arc_info[key.to_sym].empty?
            # 整形(改行置換、プレースホルダ変換)
            tag_data  = arc_info[key.to_sym]
            tag_data.gsub!("\\n", "\n")
            tag_data.gsub!("¥n", "\n")
            tag_data.gsub!("&&NAME&&", ins_name)
            tag_data.gsub!("&&FQDN&&", "#{ins_name}.#{domain}")
            reply_msg << "\n[#{key.camelcase}]"
            reply_msg << "\n#{tag_data}"
          end
          reply_msg << "```"
          message.reply(reply_msg)
        end

        # AMIの詳細情報を表示します
        def detail_ami(ami_info)
          ami_id     = ami_info[:image_id]
          basic_keys = ["image_id", "name", "state"]
          added_keys = ["spec", "desc", "param"]
          reply_msg  = "AMI[#{ami_id}]の情報だよ\n"
          reply_msg << "■基本情報\n```"
          basic_keys.each do |key|
            next if ami_info[key.to_sym].nil? or ami_info[key.to_sym].empty?
            reply_msg << sprintf("\n%-12s : %s", key.camelcase, ami_info[key.to_sym])
          end
          reply_msg << "\n```\n■付加情報\n```"
          added_keys.each do |key|
            next if ami_info[key.to_sym].nil? or ami_info[key.to_sym].empty?
            # 整形(改行置換、プレースホルダ変換)
            tag_data  = ami_info[key.to_sym]
            tag_data.gsub!("\\n", "\n")
            tag_data.gsub!("¥n", "\n")
            reply_msg << "\n[#{key.camelcase}]"
            reply_msg << "\n#{tag_data}"
          end
          reply_msg << "```"
          message.reply(reply_msg)
        end
      end
    end
  end
end
