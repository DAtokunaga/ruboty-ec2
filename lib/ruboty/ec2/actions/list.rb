require "aws-sdk"

module Ruboty
  module Ec2
    module Actions
      class List < Ruboty::Actions::Base
        def call
          message.reply(list)
        end

        private

        def list
          helper     = Ruboty::Ec2::Helpers::Common.new(message)
          aws_config = helper.get_aws_config
          source_ch  = helper.get_channel
          if !aws_config[:access_key_id] or !aws_config[:secret_access_key]
            raise "必要な環境変数が設定されていません"
          end

          ec2        = ::Aws::EC2::Client.new(aws_config)
          resp       = ec2.describe_instances
          ins_infos  = {}

          resp.reservations.each do |reservation|
            reservation.instances.each do |ins|
              owner = nil
              name  = ins_id = ins.instance_id
              ins.tags.each do |tag|
                owner = tag.value if tag.key == "Owner"
                name  = tag.value if tag.key == "Name"
              end
              next if owner.nil?
              ins_infos[name] = {}
              ins_infos[name][:name]   = name
              ins_infos[name][:owner]  = owner
              ins_infos[name][:id]     = ins_id
              ins_infos[name][:ami_id] = ins.image_id
              ins_infos[name][:type]   = ins.instance_type
              ins_infos[name][:state]  = ins.state.name
              ins_infos[name][:pub_ip] = ins.public_ip_address
            end
          end

          reply = "```\n"
          ins_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |name, ins|
            reply << sprintf("%-15s / %s / %s / %-9s / %-7s / %-13s / %s\n",
                       name, ins[:id], ins[:ami_id], ins[:type],
                       ins[:state], ins[:pub_ip], ins[:owner])
          end
          reply << "```"
        rescue => e
          e.message
        end
      end
    end
  end
end

