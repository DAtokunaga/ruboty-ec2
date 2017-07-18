module Ruboty
  module Ec2
    module Actions
      class List < Ruboty::Actions::Base
        def call
          puts "ec2 list #{message[:resource]} called"
          resource = message[:resource]
          my_ins_list   if !resource
          instance_list if resource == "instance"
          archive_list  if resource == "archive"
          ami_list      if resource == "ami"
          filtered_list if resource == "filter"
          summary       if resource == "summary"
          permit        if resource == "permit"
        end

        private

        def instance_list(filters = nil)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          ins_infos = 
            if filters.nil?
              # 全インスタンス情報取得
              ec2.get_ins_infos
            elsif filters.size == 1
              # 自分がオーナーとなっているインスタンス情報取得
              ec2.get_ins_infos(filters)
            else
              # 指定キーワードがName、Ownerタグに含まれるインスタンス情報取得
              merge_hash = {}
              filters.each do |key, val|
                merge_hash.merge!(ec2.get_ins_infos({key => val}))
              end
              merge_hash
            end

          # 応答メッセージ文字列生成
          msg_list  = ""
          ins_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ins|
            sg_names = ""
            ins[:groups].each do |sg_name, sg_id|
              next if sg_name == "default"
              next if !sg_name.index("skt-").nil?
              sg_names << "," if !sg_names.empty?
              sg_names << sg_name
            end
            msg_list << sprintf("\n[%s] %-15s | %-12s | %-14s | %-6s | %12s | %-9s | %s",
                                ins[:state_mark], name, ins[:private_ip], ins[:public_ip],
                                sg_names, ins[:parent_id], ins[:instance_type], ins[:owner])
          end
          warn_str = ""
          if filters.nil?
            warn_str  = "`#{ENV['SLACK_USERNAME']} ec2 list instance は出来るだけ使わないでね（関係ない人に通知が飛んじゃうよ）`\n"
            warn_str << "`instanceを付けずに実行するか、#{ENV['SLACK_USERNAME']} ec2 list filter {ワード}を使ってね`\n"
          end
          header_str = sprintf("[-] %s|%s|%s|%s|%s|%s|%s",
                               "- InsName ------", "- PrivateIp --", "- PublicIp -----",
                               " Access ", "- UsingAMI ---", "- Type ----", "- Owner ---")
          reply_msg  = "```#{header_str}#{msg_list}```"
          reply_msg  = "#{warn_str}#{reply_msg}" if !warn_str.empty?
          reply_msg  = "インスタンスが見つからないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def archive_list(filters = nil)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          arc_infos =
            if filters.nil?
              # 全アーカイブ情報取得
              ec2.get_arc_infos
            elsif filters.size == 1
              # 自分がオーナーとなっているアーカイブ情報取得
              ec2.get_arc_infos(filters)
            else
              # 指定キーワードがName、Ownerタグに含まれるアーカイブ情報取得
              merge_hash = {}
              filters.each do |key, val|
                merge_hash.merge!(ec2.get_arc_infos({key => val}))
              end
              merge_hash
            end

          # 応答メッセージ文字列生成
          msg_list  = ""
          arc_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            frozen = (!ami[:frozen].nil? and !ami[:frozen].empty?) ? "Y" : ""
            msg_list << sprintf("\n[%9s] %-15s | %-12s | %-12s | %1s | %s",
                                ami[:state], ami[:name], ami[:parent_id], ami[:ip_addr], frozen, ami[:owner])
          end
          warn_str = ""
          if filters.nil?
            warn_str  = "`#{ENV['SLACK_USERNAME']} ec2 list archive は出来るだけ使わないでね（関係ない人に通知が飛んじゃうよ）`\n"
            warn_str << "`archiveを付けずに実行するか、#{ENV['SLACK_USERNAME']} ec2 list filter {ワード}を使ってね`\n"
          end
          header_str = sprintf("[AMIStatus]%-15s|%-12s|%-12s|%s|%s",
                               "- InsName -------", "- UsingAMI ---",  "- PrivateIp --",
                               " F ", "- Owner ---")
          reply_msg  = "```#{header_str}#{msg_list}```"
          reply_msg  = "#{warn_str}#{reply_msg}" if !warn_str.empty?
          reply_msg  = "アーカイブが見つからないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def ami_list
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          default_ami_id = util.get_default_ami
          ami_infos = ec2.get_ami_infos
          msg_list  = ""
          ami_infos.sort {|(k1, v1), (k2, v2)| v1[:spec] <=> v2[:spec] }.each do |name, ami|
            ami_spec = ami[:spec]
            ami_spec = "#{ami[:spec]} (default)" if ami[:image_id] == default_ami_id
            msg_list << sprintf("\n%s | %s", ami[:image_id], ami_spec)
          end
          reply_msg = "```#{msg_list}```"
          reply_msg = "AMIが見つからないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def my_ins_list
          util  = Ruboty::Ec2::Helpers::Util.new(message)
          owner = util.get_caller
          id    = util.get_caller_id
          name  = util.get_caller_name

          message.reply("owned by '#{owner}'\n[インスタンス]\n")
          instance_list({'Owner' => "*#{id}*"})
          message.reply("[アーカイブ]\n")
          archive_list({'Owner' => "*#{id}*"})
        rescue => e
          message.reply(e.message)
        end

        def filtered_list
          word    = message[:word]
          filters = {'Name' => "*#{word}*", 'Owner' => "*#{word}*"}
          message.reply("filter by '#{word}'\n[インスタンス]\n")
          instance_list(filters)
          message.reply("[アーカイブ]\n")
          archive_list(filters)
        rescue => e
          message.reply(e.message)
        end

        def summary
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          ins_infos = ec2.get_ins_infos
          arc_infos = ec2.get_arc_infos

          # サマリ表示情報取得・集計
          ins_summary = {'total_count' => 0}
          ins_infos.each do |name, ins|
            ins_summary['total_count']  += 1
            ins_summary[ins[:state]] ||= 0
            ins_summary[ins[:state]]  += 1
          end
          arc_summary = {'total_count' => 0}
          arc_infos.each do |name, ami|
            arc_summary['total_count']  += 1
            arc_summary[ami[:state]] ||= 0
            arc_summary[ami[:state]]  += 1
          end

          # 応答メッセージ文字列生成
          ins_str  = "インスタンスとアーカイブを数えてみたよ\n```"
          ins_str << "Instance -> total:#{ins_summary['total_count']}"
          ins_str << ", [\u{25BA}]running:#{ins_summary['running']}" if !ins_summary['running'].nil?
          ins_str << ", [\u{25A0}]stopped:#{ins_summary['stopped']}" if !ins_summary['stopped'].nil?
          ins_str << ", [\u{25B2}]pending:#{ins_summary['pending']}" if !ins_summary['pending'].nil?
          ins_str << ", [\u{25BC}]shutting-down:#{ins_summary['shutting-down']}" if !ins_summary['shutting-down'].nil?
          ins_str << ", [\u{25BC}]stopping:#{ins_summary['stopping']}" if !ins_summary['stopping'].nil?
          ins_str << "\n"
          arc_str  = "Archive  -> total:#{arc_summary['total_count']}"
          arc_str << ", available:#{arc_summary['available']}" if !arc_summary['available'].nil?
          arc_str << ", pending:#{arc_summary['pending']}" if !arc_summary['pending'].nil?
          arc_str << ", failed:#{arc_summary['failed']}" if !arc_summary['failed'].nil?
          arc_str << "```\n"
          reply_msg  = "#{ins_str}#{arc_str}定期的に見直して、使わないものは削除してね"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def permit
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          
          ## メイン処理 ##
 
          ## インスタンス／SG情報取得
          sg_infos  = ec2.get_sg_infos
          ins_infos = ec2.get_ins_infos
 
          msg_list  = ""
          sg_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |sg_name, sg_info|
            next if sg_name == "default"
            next if !sg_name.index("skt-").nil?
            msg_list << "\n[#{sg_name}]"
            msg_list << "\n  Permitted IPs  -> #{sg_info[:ip_perms].join(',')}"
            inuse_list = []
            ins_infos.each do |name, ins|
              inuse_list << name if ins[:groups].keys.include?(sg_name)
            end
            if inuse_list.empty? 
              msg_list << "\n  Instance InUse -> なし"
            else
              msg_list << "\n  Instance InUse -> #{inuse_list.join(',')}"
            end
          end 
          header_str = "アクセス許可ポリシー(対象ポート:443/8443)の情報だよ"
          reply_msg  = "#{header_str} ```#{msg_list}```"
          message.reply(reply_msg)
        rescue => e  
          message.reply(e.message)
        end

      end
    end
  end
end
