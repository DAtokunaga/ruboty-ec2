module Ruboty
  module Ec2
    module Actions
      class Access < Ruboty::Actions::Base
        def call
          puts "ec2 access #{message[:cmd]} called"
          cmd_name = message[:cmd]
          give   if cmd_name == "give"
          revoke if cmd_name == "revoke"
        end

        private

        def give
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          sg_name  = message[:sg_name]
          sg_name  = "any" if sg_name.nil? 

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
          # 既存設定有無チェック
          ins_info = ins_infos[ins_name]
          if ins_info[:groups].size == 2
            raise "インスタンス[#{ins_name}]は既にアクセス許可設定済みだよ"
          end

          ## 指定されたSGの存在チェック
          sg_infos = ec2.get_sg_infos
          raise "セキュリティグループ[#{sg_name}]が見つからないよ" if !sg_infos.keys.include?(sg_name)

          ## メイン処理 ##

          # インスタンスにSGを追加設定
          sg_ids =  ins_info[:groups].values
          sg_ids << sg_infos[sg_name]
          ins_id =  ins_info[:instance_id]
          ec2.update_groups(ins_id, sg_ids)
          reply_msg = "インスタンス[#{ins_name}]にアクセス許可[#{sg_name}]を設定したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def revoke
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          sg_name  = message[:sg_name]
          sg_name  = "any" if sg_name.nil?

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ" if ins_infos.empty?
          # 既存設定有無チェック
          ins_info = ins_infos[ins_name]
          if ins_info[:groups].size == 1
            raise "インスタンス[#{ins_name}]はアクセス許可が設定されていないよ"
          end

          ## 指定されたSGの存在チェック
          sg_infos = ec2.get_sg_infos
          raise "セキュリティグループ[#{sg_name}]が見つからないよ" if !sg_infos.keys.include?(sg_name)

          ## メイン処理 ##

          # インスタンスにSGを追加設定
          sg_ids =  ins_info[:groups].values
          sg_ids.delete(sg_infos[sg_name])
          ins_id =  ins_info[:instance_id]
          ec2.update_groups(ins_id, sg_ids)
          reply_msg = "インスタンス[#{ins_name}]のアクセス許可設定[#{sg_name}]を解除したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
