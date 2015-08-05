module Ruboty
  module Ec2
    module Helpers
      class Common
        def initialize(message)
          @message = message
        end

        def get_aws_config
          access_key, secret_key, region = nil
          if channels = ENV['RUBOTY_EC2_CHANNELS']
            source_ch = @message.original[:source]
            raise "そのチャンネルでは実行できません" if !channels.split(",").include?(source_ch)
            access_key = ENV["RUBOTY_EC2_ACCESS_KEY_#{source_ch}"]
            secret_key = ENV["RUBOTY_EC2_SECRET_KEY_#{source_ch}"]
            region     = ENV["RUBOTY_EC2_REGION_#{source_ch}"] ||= "ap-northeast-1"
          end
          {:region => region, :access_key_id => access_key, :secret_access_key => secret_key}
        end

        def get_channel
          @message.original[:source]
        end

      end
    end
  end
end
