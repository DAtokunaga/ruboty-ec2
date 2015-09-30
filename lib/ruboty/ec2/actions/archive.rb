module Ruboty
  module Ec2
    module Actions
      class Archive < Ruboty::Actions::Base
        def call
          ins_name = message[:ins_name]
          if ins_name
            archive
          else
            archive_all
          end
        end

        private

        def archive
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
          # ステータス[停止]チェック
          ins_info = ins_infos[ins_name]
          raise "インスタンス[#{ins_name}]を先に停止プリーズ" if ins_info[:state] != "stopped"

          ## メイン処理 ##

          # アーカイブ処理実行
          ins_archive(ins_name, ins_info)
          message.reply("インスタンス[#{ins_name}]をアーカイブしたよ")
        rescue => e
          message.reply(e.message)
        end

        def archive_all
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # 警告を出すまでに日数、アーカイブ猶予期間の定義値取得
          period_archive = Ruboty::Ec2::Const::PeriodToArchive
          period_notice  = Ruboty::Ec2::Const::PeriodToArchiveNotice
          remain_days    = period_archive - period_notice

          ## メイン処理 ##

          ## 現在利用中のインスタンス情報を取得
          reply_msg = ""
          archive_list = {}
          ins_infos = ec2.get_ins_infos
          ins_infos.each do |name, ins|
            next if ins[:state] != "stopped" or !ins[:last_used_time]
            stop_days = (util.get_time_diff(ins[:last_used_time]) - 1) / 24
            if stop_days >= period_archive
              # アーカイブ
              archive_list[name] = ins
              next
            end
            if stop_days >= period_notice and stop_days < (period_notice + 1)
              reply_msg << "@#{ins[:owner]}: インスタンス[#{name}]は "
              reply_msg << "あと#{remain_days}日後にアーカイブしちゃうよ！\n"
            end
          end
          if !reply_msg.empty?
            reply_msg << "  ↑不要であればアーカイブ前に削除してね！\n"
            reply_msg << "   一度起動するとアーカイブを延期できるよ！\n\n"
          end
          archive_list.each do |name, ins|
            ins_archive(name, ins)
            reply_msg << "@#{ins[:owner]}: インスタンス[#{name}]をアーカイブしたよ\n"
          end
          message.reply(reply_msg.chomp) if !reply_msg.empty?
        rescue => e
          message.reply(e.message)
        end

        # アーカイブメソッド 
        def ins_archive(ins_name, ins_info)
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # AMI作成処理実施
          ins_id = ins_info[:instance_id]
          ami_id = ec2.create_ami(ins_id, ins_name)

          # タグ付け
          params = {
            "Name"     => ins_name,
            "Owner"    => ins_info[:owner],
            "ParentId" => ins_info[:parent_id],
            "IpAddr"   => ins_info[:private_ip],
            "Spec"     => ins_info[:spec],
            "Desc"     => ins_info[:desc]
          }
          params["Param"]      = ins_info[:param] if !ins_info[:param].nil?
          params["AutoStart"]  = ins_info[:auto_start] if !ins_info[:auto_start].nil?
          params["ExceptStop"] = ins_info[:except_stop] if !ins_info[:except_stop].nil?
          ec2.update_tags([ami_id], params)

          # インスタンス削除処理開始
          ec2.destroy_ins(ins_id)
        end

      end
    end
  end
end
