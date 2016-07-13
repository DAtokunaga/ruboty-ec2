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
        end

        private

        def instance_list(filter_str = nil)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          ins_infos   = ec2.get_ins_infos

          # サマリ表示情報取得・集計
          ins_summary = {'total_count' => 0}
          ins_filterd = {'total_count' => 0}
          ins_infos.each do |name, ins|
            ins_summary['total_count']  += 1
            ins_summary[ins[:state]] ||= 0
            ins_summary[ins[:state]]  += 1
            if !filter_str.nil?
              next if "#{name} #{ins[:owner]}".index(filter_str).nil?
              ins_filterd['total_count']  += 1
              ins_filterd[ins[:state]] ||= 0
              ins_filterd[ins[:state]]  += 1
            end
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
            next if "#{name} #{ins[:owner]}".index(filter_str).nil? if !filter_str.nil?
            msg_list << sprintf("\n[%s] %-15s | %-12s | %-14s | %-6s | %12s | %-9s | %s",
                                 ins[:state_mark], name, ins[:private_ip], ins[:public_ip],
                                 sg_names, ins[:parent_id], ins[:instance_type], ins[:owner])
          end
          header_str  = "Summary -> total:#{ins_summary['total_count']}"
          header_str << ", [\u{25BA}]running:#{ins_summary['running']}" if !ins_summary['running'].nil?
          header_str << ", [\u{25A0}]stopped:#{ins_summary['stopped']}" if !ins_summary['stopped'].nil?
          header_str << ", [\u{25B2}]pending:#{ins_summary['pending']}" if !ins_summary['pending'].nil?
          header_str << ", [\u{25BC}]shutting-down:#{ins_summary['shutting-down']}" if !ins_summary['shutting-down'].nil?
          header_str << ", [\u{25BC}]stopping:#{ins_summary['stopping']}" if !ins_summary['stopping'].nil?
          if !filter_str.nil?
            header_str << " / Filtered -> total:#{ins_filterd['total_count']}"
            header_str << ", running:#{ins_filterd['running']}" if !ins_filterd['running'].nil?
            header_str << ", stopped:#{ins_filterd['stopped']}" if !ins_filterd['stopped'].nil?
            header_str << ", pending:#{ins_filterd['pending']}" if !ins_filterd['pending'].nil?
            header_str << ", shutting-down:#{ins_filterd['shutting-down']}" if !ins_filterd['shutting-down'].nil?
            header_str << ", stopping:#{ins_filterd['stopping']}" if !ins_filterd['stopping'].nil?
          end
          header_str << "\n"
          header_str << sprintf("[-] %s|%s|%s|%s|%s|%s|%s",
                                "- InsName ------", "- PrivateIp --", "- PublicIp -----",
                                " Access ", "- UsingAMI ---", "- Type ----", "- Owner ---")
          warn_str  = ""
          if filter_str.nil?
            warn_str  = "`#{ENV['SLACK_USERNAME']} ec2 list instance は出来るだけ使わないでね（関係ない人に通知が飛んじゃうよ）`\n"
            warn_str << "`instanceを付けずに実行するか、#{ENV['SLACK_USERNAME']} ec2 list filter {ワード}を使ってね`\n"
          end
          reply_msg  = "```#{header_str}#{msg_list}```"
          reply_msg  = "#{warn_str}#{reply_msg}" if !warn_str.empty?
          reply_msg  = "インスタンスが見つからないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def archive_list(filter_str = nil)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          arc_infos = ec2.get_arc_infos

puts "arc count: #{arc_infos.size}"

          # サマリ表示情報取得・集計
          arc_summary = {'total_count' => 0}
          arc_filterd = {'total_count' => 0}
          arc_infos.each do |name, ami|
            arc_summary['total_count']  += 1
            arc_summary[ami[:state]] ||= 0
            arc_summary[ami[:state]]  += 1
            if !filter_str.nil?
              next if "#{name} #{ami[:owner]}".index(filter_str).nil?
              arc_filterd['total_count'] += 1
              arc_filterd[ami[:state]] ||= 0
              arc_filterd[ami[:state]]  += 1
            end
          end

puts "arc count up for summary"

          # 応答メッセージ文字列生成
          msg_list  = ""
          arc_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            next if "#{name} #{ami[:owner]}".index(filter_str).nil? if !filter_str.nil?
            frozen = (!ami[:frozen].nil? and !ami[:frozen].empty?) ? "Y" : ""
            msg_list << sprintf("\n[%9s] %-15s | %-12s | %-12s | %1s | %s",
                         ami[:state], ami[:name], ami[:parent_id], ami[:ip_addr], frozen, ami[:owner])
puts "generate msg_list: #{name}"
          end
          header_str  = "Summary -> total:#{arc_summary['total_count']}"
          header_str << ", available:#{arc_summary['available']}" if !arc_summary['available'].nil?
          header_str << ", pending:#{arc_summary['pending']}" if !arc_summary['pending'].nil?
          header_str << ", failed:#{arc_summary['failed']}" if !arc_summary['failed'].nil?
          if !filter_str.nil?
            header_str << " / Filtered -> total:#{arc_filterd['total_count']}"
            header_str << ", available:#{arc_filterd['available']}" if !arc_filterd['available'].nil?
            header_str << ", pending:#{arc_filterd['pending']}" if !arc_filterd['pending'].nil?
            header_str << ", failed:#{arc_filterd['failed']}" if !arc_filterd['failed'].nil?
          end
          header_str << "\n"
          header_str << sprintf("[AMIStatus]%-15s|%-12s|%-12s|%s|%s",
                                "- InsName -------", "- UsingAMI ---",  "- PrivateIp --",
                                " F ", "- Owner ---")
puts "generate header_str: #{header_str}"
          warn_str  = ""
          if filter_str.nil?
            warn_str  = "`#{ENV['SLACK_USERNAME']} ec2 list archive は出来るだけ使わないでね（関係ない人に通知が飛んじゃうよ）`\n"
            warn_str << "`archiveを付けずに実行するか、#{ENV['SLACK_USERNAME']} ec2 list filter {ワード}を使ってね`\n"
          end
          reply_msg  = "```#{header_str}#{msg_list}```"
          reply_msg  = "#{warn_str}#{reply_msg}" if !warn_str.empty?
          reply_msg  = "アーカイブが見つからないよ" if msg_list.empty?
puts "generate reply_msg: #{reply_msg}"
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

          message.reply("owned by '#{owner}'\n[インスタンス]\n")
          instance_list(" #{owner}")
          message.reply("[アーカイブ]\n")
          archive_list(" #{owner}")
        rescue => e
          message.reply(e.message)
        end

        def filtered_list
          word = message[:word]
          message.reply("filter by '#{word}'\n[インスタンス]\n")
          instance_list(word)
          message.reply("[アーカイブ]\n")
          archive_list(word)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
