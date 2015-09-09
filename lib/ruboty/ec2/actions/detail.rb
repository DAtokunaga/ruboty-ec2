module Ruboty
  module Ec2
    module Actions
      class Detail < Ruboty::Actions::Base
        def call
          detail
        end

        private

        def detail
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          target_info = {}
          ins_infos = ec2.get_ins_infos(ins_name)
          # インスタンス存在チェック
          if ins_infos.empty?
            arc_infos = ec2.get_arc_infos(ins_name)
            # アーカイブ存在チェック
            if arc_infos.empty?
              raise "インスタンス[#{ins_name}]が見つからないよ" if ins_name.index("ami-").nil?
              ami_infos = ec2.get_ami_infos
              # AMI存在チェック
              if ami_infos.include?(ins_name)
                target_info = ami_infos[ins_name]
              else
                raise "インスタンス[#{ins_name}]が見つからないよ"
              end
            else
              # ステータス[available]チェック
              arc_info  = arc_infos[ins_name]
              if !["pending", "available"].include?(arc_info[:state])
                raise "アーカイブ[#{ins_name}]は今使えないっす..."
              end
              target_info = arc_info
            end
          else
            target_info = ins_infos[ins_name]
          end

          ## メイン処理 ##

          # 表示するタグ名を指定
          display_tags = ["spec", "desc", "param"]
          ins_or_arc = (target_info[:instance_id].nil? ? "アーカイブ" : "インスタンス")
          ins_or_arc = "AMI" if target_info[:ami_name].nil?
          reply_msg  = "#{ins_or_arc}[#{ins_name}]の詳細情報だよ\n"
          display_tags.each do |tag|
            next if target_info[tag.to_sym].nil? or target_info[tag.to_sym].empty?
            # 整形(改行置換、プレースホルダ変換)
            tag_data  = target_info[tag.to_sym]
            tag_data.gsub!("\\n", "\n")
            tag_data.gsub!("¥n", "\n")
            tag_data.gsub!("%%NAME%%", ins_name)
            tag_data.gsub!("%%FQDN%%", "#{ins_name}.#{util.get_domain}")
            reply_msg << "[#{tag.camelcase}]\n"
            reply_msg << "```#{tag_data}```\n"
          end
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
