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
          ins_infos = ec2.get_ins_infos
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
          header_str = "↓凡例．[\u{25B2}]->pending, [\u{25BA}]->running, [\u{25BC}]->shutting-down/stopping, [\u{25A0}]->stopped\n"
          header_str << sprintf("[-] %s|%s|%s|%s|%s|%s|%s",
                                "- InsName ------", "- PrivateIp --", "- PublicIp -----",
                                " Access ", "- UsingAMI ---", "- Type ----", "- Owner ---")
          reply_msg  = "```#{header_str}#{msg_list}```"
          reply_msg  = "インスタンスが見つからないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def archive_list(filter_str = nil)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          arc_infos = ec2.get_arc_infos
          msg_list  = ""
          arc_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            next if "#{name} #{ami[:owner]}".index(filter_str).nil? if !filter_str.nil?
            frozen = (!ami[:frozen].nil? and !ami[:frozen].empty?) ? "Y" : ""
            msg_list << sprintf("\n[%9s] %-15s | %-12s | %-12s | %1s | %s",
                         ami[:state], ami[:name], ami[:parent_id], ami[:ip_addr], frozen, ami[:owner])
          end
          header_str = sprintf("[AMIStatus]%-15s|%-12s|%-12s|%s|%s",
                                "- InsName -------", "- UsingAMI ---",  "- PrivateIp --",
                                " F ", "- Owner ---")
          reply_msg  = "```\n#{header_str}#{msg_list}```"
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
