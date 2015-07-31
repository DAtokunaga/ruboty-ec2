require "aws-sdk"

module Ruboty
  module Ec2
    module Actions
      class List < Ruboty::Actions::Base
        def call
          access_key = ENV['RUBOTY_AWS_ACCESS_KEY_ID']
          secret_key = ENV['RUBOTY_AWS_SECRET_ACCESS_KEY']
          region     = ENV['RUBOTY_AWS_EC2_REGIONS'] ||= 'ap-northeast-1'

          reply = "```\n"
          ec2   = ::Aws::EC2::Client.new({:region => region, :access_key_id => access_key, :secret_access_key => secret_key})
          resp  = ec2.describe_instances
          resp.reservations.each do |reservation|
            reservation.instances.each do |instance|
              reply += "#{instance.instance_id} "
            end
          end
          reply += "\n```"
          message.reply("#{reply}")
        end
      end
    end
  end
end
