module Ruboty
  module Ec2
    module Actions
      class Thaw < Ruboty::Actions::Base
        def call
          puts "ec2 thaw #{message[:ins_name]} called"
          thaw
        end

        private

        def thaw
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 事前チェック ##

          ## 現在利用中のアーカイブ情報を取得
          arc_infos = ec2.get_arc_infos({'Name' => ins_name})
          # 存在チェック
          raise "アーカイブ[#{ins_name}]が見つからないよ" if arc_infos.empty?
          # 既存設定有無チェック
          arc_info = arc_infos[ins_name]
          if arc_info[:frozen].nil? or arc_info[:frozen].empty?
            raise "アーカイブ[#{ins_name}]は凍結されていないよ"
          end

          ## メイン処理 ##

          # 凍結解除アーカイブ設定（タグ付け）
          params =  ["Frozen"]
          ec2.delete_tags([arc_info[:image_id]], params)
          reply_msg = "アーカイブ[#{ins_name}]を凍結解除したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
