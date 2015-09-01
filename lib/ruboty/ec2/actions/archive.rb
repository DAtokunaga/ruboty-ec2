module Ruboty
  module Ec2
    module Actions
      class Archive < Ruboty::Actions::Base
        def call
          ins_name = message[:ins_name]
          if ins_name
            message.reply(archive)
          else
            message.reply(archive_all)
          end
        end

        private

        def archive
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          if ins_infos.empty?
            ami_infos = ec2.get_ami_infos(ins_name)
            raise "インスタンス[#{ins_name}]は存在しないよー" if ami_infos.empty?
            raise "インスタンス[#{ins_name}]はアーカイブ済みだよ"
          end

          # ステータス[停止]チェック
          ins_info = ins_infos[ins_name]
          raise "アーカイブ前にインスタンス[#{ins_name}]を停止してね" if ins_info[:state] != "stopped"

          # アーカイブ処理実行
          ins_archive(ins_name, ins_info)
          "インスタンス[#{ins_name}]をアーカイブしたよ"
        rescue => e
          e.message
        end

        def archive_all
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          period_archive = Ruboty::Ec2::Const::PeriodToArchive
          period_notice  = Ruboty::Ec2::Const::PeriodToArchiveNotice
          remain_days    = period_archive - period_notice

          ## 現在利用中のインスタンス情報を取得
          reply = ""
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
            if stop_days >= period_notice
              reply << "@#{ins[:owner]}: インスタンス[#{name}]は "
              reply << "あと#{remain_days}日後にアーカイブします！\n"
            end
          end
          reply << "  ↑不要であればアーカイブ前に削除してね！\n\n" if !reply.empty?
          archive_list.each do |name, ins|
            ins_archive(name, ins)
            reply << "@#{ins[:owner]}: インスタンス[#{name}]をアーカイブしたよ\n"
          end
          reply
        rescue => e
          e.message
        end

        def ins_archive(ins_name, ins_info)
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # AMI作成処理実施
          ins_id = ins_info[:instance_id]
          ami_id = ec2.create_ami(ins_id, ins_name)

          # タグ付け
          params =  {"Name"  => ins_name, "Owner" => ins_info[:owner]}
          params["IpAddr"]  = ins_info[:private_ip] if !ins_info[:private_ip].nil?
          params["Spec"]    = ins_info[:spec]       if !ins_info[:spec].nil?
          params["Desc"]    = ins_info[:desc]       if !ins_info[:desc].nil?
          params["Param"]   = ins_info[:param]      if !ins_info[:param].nil?
          ec2.update_tags(ami_id, params)

          # インスタンス削除処理開始
          ec2.destroy_ins(ins_id)
        rescue => e
          e.message
        end

      end
    end
  end
end
