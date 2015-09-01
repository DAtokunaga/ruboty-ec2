module Ruboty
  module Ec2
    module Actions
      class Archive < Ruboty::Actions::Base
        def call
          ins_name = message[:ins_name]
          if ins_name
            message.reply(archive)     if ins_name
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
          caller   = util.get_caller

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

          # AMI作成処理実施
          ins_id = ins_info[:instance_id]
          ami_id = ec2.create_ami(ins_id, ins_name)

          # タグ付け
          params =  {"Name"  => ins_name, "LastUsedTime" => Time.now.to_s}
          params["IpAddr"]  = ins_info[:private_ip] if !ins_info[:private_ip].nil?
          params["Spec"]    = ins_info[:spec]       if !ins_info[:spec].nil?
          params["Desc"]    = ins_info[:desc]       if !ins_info[:desc].nil?
          params["Param"]   = ins_info[:param]      if !ins_info[:param].nil?
          ec2.update_tags(ami_id, params)

          # インスタンス削除処理開始
          ec2.destroy_ins(ins_id)

          "インスタンス[#{ins_name}]をアーカイブしたよ"
        rescue => e
          e.message
        end

        def archive_all
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          caller   = util.get_caller

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

          # AMI作成処理実施
          ins_id = ins_info[:instance_id]
          ami_id = ec2.create_ami(ins_id, ins_name)

          # タグ付け
          params =  {"Name"  => ins_name, "Owner" => caller, "LastUsedTime" => Time.now.to_s}
          params["IpAddr"]  = ins_info[:private_ip] if !ins_info[:private_ip].nil?
          params["Spec"]    = ins_info[:spec]       if !ins_info[:spec].nil?
          params["Desc"]    = ins_info[:desc]       if !ins_info[:desc].nil?
          params["Param"]   = ins_info[:param]      if !ins_info[:param].nil?
          ec2.update_tags(ami_id, params)

          # インスタンス削除処理開始
          ec2.destroy_ins(ins_id)

          "インスタンス[#{ins_name}]をアーカイブしたよ"
        rescue => e
          e.message
        end

      end
    end
  end
end
