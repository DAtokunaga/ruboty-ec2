require 'pp'

module Ruboty
  module Ec2
    module Actions
      class Owner < Ruboty::Actions::Base
        def call
          puts "ec2 owner #{message[:cmd]} called"
          cmd_name = message[:cmd]
          ins_name = message[:ins_name]
          to_user  = message[:to_user]
          transfer if cmd_name == "transfer" and !ins_name.nil? and !to_user.nil?
          absence  if cmd_name == "absence"
        end

        private

        def transfer
          # AWSアクセス、その他ユーティリティのインスタンス化
          brain = Ruboty::Ec2::Helpers::Brain.new(message)
          ec2   = Ruboty::Ec2::Helpers::Ec2.new(message)
          slack = Ruboty::Ec2::Helpers::Slack.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          to_user  = message[:to_user]
          
          ## 事前チェック ##

          # Slackユーザ名の一覧取得（今日初であればSlackAPIで取得してRedis保存）
          today = Time.now.strftime('%Y-%m-%d')
          brain_user_list = brain.get_slack_user_list
          slack_user_list = nil
          if brain_user_list.empty? or brain_user_list[:last_update] != today
            puts "need to get slack user list by slack api"
            slack_user_list = slack.get_slack_user_list
            brain.save_slack_user_list(slack_user_list)
          else
            puts "found slack user list in brain"
            slack_user_list = brain_user_list[:user_info]
          end
          # Slackユーザリスト取得成否チェック
          raise "Slackユーザリストが取得できなかったよ..." if slack_user_list.empty?

          ## 現在利用中のインスタンス／アーカイブ情報を取得
          ins_infos = ec2.get_ins_infos(ins_name)
          arc_infos = ec2.get_arc_infos(ins_name)

          ## インスタンス存在チェック
          if ins_infos[ins_name].nil? and arc_infos[ins_name].nil?
            raise "インスタンス[#{ins_name}]が見つからないよ"
          end

          # Owner チェック
          ins_or_arc = ''
          resrc_id   = ''
          fr_user    = ''
          unless ins_infos[ins_name].nil?
            ins_or_arc = 'インスタンス'
            resrc_id   = ins_infos[ins_name][:instance_id]
            fr_user    = ins_infos[ins_name][:owner]
          else
            ins_or_arc = 'アーカイブ'
            resrc_id   = arc_infos[ins_name][:image_id]
            fr_user    = arc_infos[ins_name][:owner]
          end
          if fr_user == to_user
            raise "#{ins_or_arc}[#{ins_name}]のオーナーは既に[#{fr_user}]だよ"
          end

          # Slackユーザ存在／ステータスチェック
          if slack_user_list[to_user].nil?
            raise "Slackユーザ[#{to_user}]は存在しないよ"
          elsif slack_user_list[to_user][:disabled]
            raise "Slackユーザ[#{to_user}]は無効化されているよ"
          end

          ## メイン処理 ##

          # タグ付け(オーナー変更)
          params =  {"Owner" => to_user}
          ec2.update_tags([resrc_id], params)

          reply_msg  = "#{ins_or_arc}[#{ins_name}]のオーナーを[#{to_user}]に変更したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def absence
          # AWSアクセス、その他ユーティリティのインスタンス化
          brain = Ruboty::Ec2::Helpers::Brain.new(message)
          ec2   = Ruboty::Ec2::Helpers::Ec2.new(message)
          slack = Ruboty::Ec2::Helpers::Slack.new(message)

          ## 事前チェック ##

          # Slackユーザ名の一覧取得（今日初であればSlackAPIで取得してRedis保存）
          today = Time.now.strftime('%Y-%m-%d')
          brain_user_list = brain.get_slack_user_list
          slack_user_list = nil
          if brain_user_list.empty? or brain_user_list[:last_update] != today
            puts "need to get slack user list by slack api"
            slack_user_list = slack.get_slack_user_list
            brain.save_slack_user_list(slack_user_list)
          else
            puts "found slack user list in brain"
            slack_user_list = brain_user_list[:user_info]
          end
          # Slackユーザリスト取得成否チェック
          raise "Slackユーザリストが取得できなかったよ..." if slack_user_list.empty?

          ## メイン処理 ##

          ## 現在利用中のインスタンス／アーカイブ情報を取得
          ins_infos = ec2.get_ins_infos
          arc_infos = ec2.get_arc_infos

          # OwnerがSlackユーザリストに存在しないものを抽出して表示
          header_str = sprintf(" %15s | %18s | %s ",
                               "- InsName -----", "- Owner ----------",  "- Status ------")
          msg_list   = ""
          ins_infos.each do |ins_name, ins_info|
            owner = ins_info[:owner]
            next if owner.nil? or owner.empty?
            if !slack_user_list.has_key?(owner)
              msg_list << sprintf("\n %-15s | %-18s | Not Found", ins_name, owner)
            elsif slack_user_list[owner][:disabled]
              msg_list << sprintf("\n %-15s | %-18s | Disabled", ins_name, owner)
            end
          end
          reply_msg = "[インスタンス]\n```#{header_str}#{msg_list}```\n"
          reply_msg = "[インスタンス]\nオーナー設定に問題はないよ\n" if msg_list.empty?
          message.reply(reply_msg)

          msg_list   = ""
          arc_infos.each do |arc_name, arc_info|
            owner = arc_info[:owner]
            next if owner.nil? or owner.empty?
            if !slack_user_list.has_key?(owner)
#              msg_list << sprintf("\n %-15s | %-18s | Not Found", arc_name, owner)
            elsif slack_user_list[owner][:disabled]
#              msg_list << sprintf("\n %-15s | %-18s | Disabled", arc_name, owner)
            end
          end
          reply_msg = "[アーカイブ]\n```#{header_str}#{msg_list}```"
          reply_msg = "[アーカイブ]\nオーナー設定に問題はないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
