module Ruboty
  module Ec2
    module Actions
      class Freeze < Ruboty::Actions::Base
        def call
          puts "ec2 freeze #{message[:ins_name]} called"
          freeze
        end

        private

        def freeze
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          caller   = util.get_caller

          ## 事前チェック ##

          ## 現在利用中のアーカイブ情報を取得
          arc_infos = ec2.get_arc_infos({'Name' => ins_name})
          # 存在チェック
          raise "アーカイブ[#{ins_name}]が見つからないよ" if arc_infos.empty?
          # 既存設定有無チェック
          arc_info = arc_infos[ins_name]
          if !arc_info[:frozen].nil? and !arc_info[:frozen].empty?
            raise "アーカイブ[#{ins_name}]は既に凍結されてるよ"
          end

          ## メイン処理 ##

          # 凍結対象インスタンス設定（タグ付け）
          tag_value = "set at #{util.now} by #{caller}"
          params =  {"Frozen" => tag_value}
          ec2.update_tags([arc_info[:image_id]], params)
          reply_msg = "アーカイブ[#{ins_name}]を凍結(extract,destroy禁止)したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
