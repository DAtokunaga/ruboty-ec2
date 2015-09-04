module Ruboty
  module Ec2
    module Actions
      class Destroy < Ruboty::Actions::Base
        def call
          destroy
        end

        private

        def destroy
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          caller   = util.get_caller

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          arc_infos = ec2.get_arc_infos(ins_name)
          # アーカイブ存在チェック
          if arc_infos.empty?
            ins_infos = ec2.get_ins_infos(ins_name)
            # インスタンス存在チェック
            raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
            # ステータス[停止]チェック
            ins_info = ins_infos[ins_name]
            raise "インスタンス[#{ins_name}]を先に停止プリーズ" if ins_info[:state] != "stopped"
            if caller != ins_info[:owner]
              raise "インスタンス[#{ins_name}]を削除できるのはオーナー[#{ins_info[:owner]}]だけだよ"
            end

            # 削除処理実施
            ins_id = ins_info[:instance_id]
            ec2.destroy_ins(ins_id)
            message.reply("インスタンス[#{ins_name}]を削除したよ")
          else
            arc_info = arc_infos[ins_name]
            if caller != arc_info[:owner]
              raise "アーカイブ[#{ins_name}]を削除できるのはオーナー[#{arc_info[:owner]}]だけだよ"
            end
            # アーカイブ削除
            ec2.destroy_ami(arc_info[:image_id], arc_info[:snapshot_id])
            message.reply("アーカイブ[#{ins_name}]を削除したよ")
          end
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end

