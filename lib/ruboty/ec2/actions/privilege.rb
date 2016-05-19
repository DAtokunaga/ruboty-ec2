module Ruboty
  module Ec2
    module Actions
      class Privilege < Ruboty::Actions::Base
        def call
          puts "ec2 privilege list called"
          privilege_list
        end

        private

        def privilege_list
          util = Ruboty::Ec2::Helpers::Util.new(message)

          # 権限リスト取得
          privileges =  util.get_privilege

          # 応答メッセージ文字列生成
          sakutto_owner = ""
          reply_msg  = ""
          if !privileges[:super_admin].empty?
            reply_msg << "[さくっと管理者]   _←全てのさくっとチャンネルで全てのコマンドを実行できるよ_"
            reply_msg << "\n```#{privileges[:super_admin].join(', ')}```\n\n"
            sakutto_owner = privileges[:super_admin].first
          end
          if !privileges[:channel_admin].empty?
            reply_msg << "[チャンネル管理者] _←そのチャンネルで全てのコマンドを実行できるよ_\n```\n"
            reply_msg << "- Channel ---|- AdminNames ----------------------------------------------------"
            privileges[:channel_admin].each do |channel, admins|
              if admins.empty?
                reply_msg << sprintf("\n %-11s | %s", channel,
                                      "チャンネル管理者が設定されていないよ. ")
                reply_msg << "早めに決めて #{sakutto_owner} まで連絡してね" if !sakutto_owner.empty?
              else
                reply_msg << sprintf("\n %-11s | %s", channel, admins.join(', '))

              end
            end
            reply_msg << "\n```\n\n"
          end
          if !privileges[:restrict_command].empty?
            reply_msg << "[制限コマンド実行可能ユーザ] _←そのチャンネルの制限コマンドを実行できるユーザだよ_\n```\n"
            reply_msg << "- Channel ---|- Command -|- UserNames ----------------------------------------"
            privileges[:restrict_command].each do |channel, rstrct_cmd|
              rstrct_cmd.each do |command, users|
                if !users.empty?
                  reply_msg << sprintf("\n %-11s | %-9s | %s", channel, command, users.join(', '))
                else
                  reply_msg << sprintf("\n %-11s | %-9s | %s", channel, command,
                                       "ユーザ指定されていないので、管理者だけが実行できるよ")
                end
              end
            end
            reply_msg << "\n```\n"
            reply_msg << "ここに表示されていないコマンドは誰でも実行できるよ"
          end
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
