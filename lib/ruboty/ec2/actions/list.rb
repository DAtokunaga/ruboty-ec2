require "aws-sdk"

module Ruboty
  module Ec2
    module Actions
      class List < Ruboty::Actions::Base
        def call
          resource = message[:resource]
          instance_list if !resource
          instance_list if resource == "instance"
          archive_list  if resource == "archive"
          ami_list      if resource == "ami"
        end

        private

        def instance_list
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          ins_infos = ec2.get_ins_infos
          msg_list  = ""
          ins_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ins|
            msg_list << sprintf("\n[%s] %-15s / %s / %12s / %-9s / %s",
                                 ins[:state_mark], name, ins[:instance_id],
                                 ins[:parent_id], ins[:instance_type], ins[:owner])
          end
          legend_str = "凡例．[\u{25B2}]->pending, [\u{25BA}]->running, [\u{25BC}]->shutting-down/stopping, [\u{25A0}]->stopped"
          reply_msg  = "```#{legend_str}#{msg_list}```"
          reply_msg  = "インスタンスはまだ１つもないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def archive_list
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          arc_infos = ec2.get_arc_infos
          msg_list  = ""
          arc_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            msg_list << sprintf("\n[%9s] %-15s / %12s / %-15s / %s",
                         ami[:state], ami[:name], ami[:parent_id], ami[:ip_addr], ami[:owner])
          end
          reply_msg = "```#{msg_list}```"
          reply_msg = "アーカイブはまだ１つもないよ" if msg_list.empty?
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
          ami_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            ami_spec = ami[:spec]
            ami_spec = "#{ami[:spec]} (default)" if ami[:image_id] == default_ami_id
            msg_list << sprintf("\n%s / %s", ami[:image_id], ami_spec)
          end
          reply_msg = "```#{msg_list}```"
          reply_msg = "AMIはまだ１つもないよ" if msg_list.empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end

