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
          reply_msg = ""
          ins_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ins|
            reply_msg << sprintf("[%s] %-15s / %s / %s / %-9s / %s\n",
                                 ins[:state_mark], name, ins[:instance_id],
                                 ins[:parent_id], ins[:instance_type], ins[:owner])
          end
          if !reply_msg.empty?
            message.reply(reply_msg.chomp, code: true)
          else
            message.reply("インスタンスはまだ１つもないよ")
          end
        rescue => e
          message.reply(e.message)
        end

        def archive_list
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          arc_infos = ec2.get_arc_infos

          reply_msg = ""
          arc_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            reply_msg << sprintf("[%7s] %-15s / %s / %-15s / %s\n",
                         ami[:state], ami[:name], ami[:parent_id], ami[:ip_addr], ami[:owner])
          end
          if !reply_msg.empty?
            message.reply(reply_msg.chomp, code: true)
          else
            message.reply("アーカイブはまだ１つもないよ")
          end
        rescue => e
          message.reply(e.message)
        end

        def ami_list
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          default_ami_id = util.get_default_ami
          ami_infos = ec2.get_ami_infos

          reply_msg = ""
          ami_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ami|
            ami_spec = ami[:spec]
            ami_spec = "#{ami[:spec]} (default)" if ami[:image_id] == default_ami_id
            reply_msg << sprintf("[%s] %s\n", ami[:image_id], ami_spec)
          end
          message.reply(reply_msg.chomp, code: true)
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end

