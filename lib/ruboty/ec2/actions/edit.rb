module Ruboty
  module Ec2
    module Actions
      class Edit < Ruboty::Actions::Base
        def call
          edit
        end

        private

        def edit
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          tag_name = message[:tag_name]
          tag_key  = tag_name.camelcase
          new_data = message[:data].gsub("\n", "¥n")

          ## 事前チェック ##

          # data サイズチェック
          raise "dataは250文字以内にしてね" if new_data.size > 250

          ## 現在利用中のインスタンス情報を取得
          ins_infos   = ec2.get_ins_infos(ins_name)
          resource_id = nil
          old_data    = nil
          # インスタンス存在チェック
          if ins_infos.empty?
            arc_infos = ec2.get_arc_infos(ins_name)
            # アーカイブ存在チェック
            raise "インスタンス[#{ins_name}]が見つからないよ" if arc_infos.empty?
            # ステータス[available]チェック
            arc_info = arc_infos[ins_name]
            if !["pending", "available"].include?(arc_info[:state])
              raise "アーカイブ[#{ins_name}]は今使えないっす..."
            end
            resource_id = arc_info[:image_id]
            old_data    = arc_info[tag_name.to_sym]
          else
            ins_info    = ins_infos[ins_name]
            resource_id = ins_info[:instance_id]
            old_data    = ins_info[tag_name.to_sym]
          end

          ## メイン処理 ##

          # タグ書き換え
          params  = {tag_key => new_data}
          ec2.update_tags([resource_id], params)

          # 整形(改行置換）
          new_data!.gsub("\\n", "\n")
          new_data!.gsub("¥n", "\n")
          formatted_data = new_data

          reply_msg  = "#{tag_key}タグを編集したよ\n"
          reply_msg << "Before(no format for revert):\n"
          reply_msg << "```#{old_data}```\n"
          reply_msg << "After:\n"
          reply_msg << "```#{formatted_data}```"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
