require "aws-sdk"

module Ruboty
  module Ec2
    module Actions
      class List < Ruboty::Actions::Base
        def call
          resource = message[:resource]
          message.reply(workspace_list) if !resource
          message.reply(workspace_list) if resource === "workspace"
          message.reply(archive_list)   if resource === "archive"
          message.reply(ami_list)       if resource === "ami"
        end

        private

        def workspace_list
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          ins_infos = ec2.get_ins_infos

          reply = "```\n"
          ins_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ins|
            reply << sprintf("[%s] %-15s / %s / %s / %-9s / %s\n",
                             ins[:state_mark], name, ins[:instance_id],
                             ins[:image_id], ins[:instance_type], ins[:owner])
          end
          reply << "```"
        rescue => e
          e.message
        end

        def archive_list
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          ami_infos = ec2.get_ami_infos

          reply = "```\n"
          ami_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            # Owner, IpAddrタグを持つAMIが対象
            next if !ami[:owner] or !ami[:ip_addr]
            reply << sprintf("[%7s] %-15s / %s / %-15s / %s\n",
                       ami[:state], ami[:name], ami[:image_id], ami[:ip_addr], ami[:owner])
          end
          reply << "```"
        rescue => e
          e.message
        end

        def ami_list
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          ami_infos = ec2.get_ami_infos

          reply = "```\n"
          ami_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            # Owner, IpAddrタグを持たず、Specタグを持つAMIが対象
            next if ami[:owner] and ami[:ip_addr]
            next if !ami[:spec]
            reply << sprintf("[%s] %s\n", ami[:image_id], ami[:spec])
          end
          reply << "```"
        rescue => e
          e.message
        end
      end
    end
  end
end

