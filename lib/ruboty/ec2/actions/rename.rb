module Ruboty
  module Ec2
    module Actions
      class Rename < Ruboty::Actions::Base
        def call
          puts "ec2 rename #{message[:old_ins_name]} #{message[:new_ins_name]} called"
          rename
        end

        private

        def rename
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          old_ins_name = message[:old_ins_name]
          new_ins_name = message[:new_ins_name]

          ## 事前チェック ##

          # インスタンス名チェック
          if !new_ins_name.match(/^[a-z0-9\-]+$/) or new_ins_name.length > 15
            warn_msg =  "インスタンス名は↓このルールで指定してね\n"
            warn_msg << "```\n"
            warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
            warn_msg << "  文字列長 -> 15文字以内"
            warn_msg << "```"
            raise warn_msg
          end
          raise "同じインスタンス名は指定できないよ" if old_ins_name == new_ins_name

          ## 現在利用中のインスタンス／AMIの情報を取得
          ins_infos = ec2.get_ins_infos
          arc_infos = ec2.get_arc_infos

          # リネーム元チェック
          raise "インスタンス[#{old_ins_name}]が見つからないよ" if ins_infos[old_ins_name].nil?
          old_ins_info = ins_infos[old_ins_name]
          raise "インスタンス[#{old_ins_name}]を先に停止プリーズ" if old_ins_info[:state] != "stopped"

          # リネーム先チェック
          if !ins_infos[new_ins_name].nil? or !arc_infos[new_ins_name].nil?
            raise "リネーム先インスタンス[#{new_ins_name}]は既にあるよ"
          end

          ## メイン処理 ##

          # タグ付け
          ins_id = old_ins_info[:instance_id]
          params = {"Name"  => new_ins_name}
          ec2.update_tags([ins_id], params)

          # メッセージ
          message.reply("インスタンス[#{old_ins_name}]の名前を[#{new_ins_name}]に変更したよ")
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
