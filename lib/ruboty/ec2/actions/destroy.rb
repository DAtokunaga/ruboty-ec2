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
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          r53  = Ruboty::Ec2::Helpers::Route53.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          caller   = util.get_caller

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          if ins_infos.empty?
            arc_infos = ec2.get_arc_infos(ins_name)
            raise "インスタンス[#{ins_name}]は存在しないよー" if arc_infos.empty?
            raise "インスタンス[#{ins_name}]はアーカイブ済みだよ"
          end

# TODO: アーカイブされたファイルも削除できるように変更

          # ステータス[停止]チェック
          ins_info = ins_infos[ins_name]
          raise "インスタンス[#{ins_name}]を先に停止プリーズ" if ins_info[:state] != "stopped"
          if caller != ins_info[:owner]
            raise "インスタンス[#{ins_name}]を削除できるのはオーナー[#{ins_info[:owner]}]だけだよ"
          end

          # 削除処理実施
          ins_id = ins_info[:instance_id]
          ec2.destroy_ins(ins_id)

          # Route53 レコード削除処理
          r53.delete_record_sets(ins_name, ins_info[:public_ip])

          message.reply("インスタンス[#{ins_name}]を削除したよ")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end

