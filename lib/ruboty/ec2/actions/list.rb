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
          raise "必要な環境変数が設定されていません" if !aws_config[:access_key_id] or !aws_config[:secret_access_key]

          reply = "```\n#{Time.now}\n"
          reply << "this channel is #{source_ch}\n"
          ec2   = ::Aws::EC2::Client.new(aws_config)
          resp  = ec2.describe_instances
          resp.reservations.each do |reservation|
            reservation.instances.each do |instance|
              reply << "#{instance.instance_id} "
            end
          end
          reply << "\n```"
        rescue => e
          e.message
        end
      end
    end
  end
end
