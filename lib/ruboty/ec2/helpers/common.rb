require 'ipaddr'

module Ruboty
  module Ec2
    module Helpers
      class Common
        def initialize(message)
          @msg = message
          check_channel
        end

        def check_channel
          if channels = ENV['RUBOTY_EC2_CHANNELS']
            from_ch = get_channel
            raise "そのチャンネルでは実行できません" if !channels.split(",").include?(from_ch)
          else
            raise "必要な環境変数が設定されていません"
          end
        end

        def get_aws_config
          from_ch    = get_channel
          access_key = ENV["RUBOTY_EC2_ACCESS_KEY_#{from_ch}"]
          secret_key = ENV["RUBOTY_EC2_SECRET_KEY_#{from_ch}"]
          region     = ENV["RUBOTY_EC2_REGION_#{from_ch}"] ||= "ap-northeast-1"
          {:region => region, :access_key_id => access_key, :secret_access_key => secret_key}
        end

        def get_domain
          from_ch   = get_channel
          domain    = ENV["RUBOTY_EC2_DOMAIN_#{from_ch}"]
          raise "必要な環境変数が設定されていません" if domain.nil?
          domain
        end

        def get_subnet_id
          from_ch   = get_channel
          subnet_id = ENV["RUBOTY_EC2_SUBNET_ID_#{from_ch}"]
          raise "必要な環境変数が設定されていません" if subnet_id.nil?
          subnet_id
        end

        def get_channel
          @msg.original[:from] ? @msg.original[:from].split("@").first : "shell"
        end

        def get_usable_iprange(subnet_cidr)
          iprange_array = []
          iprange_range = IPAddr.new(subnet_cidr).to_range
          iprange_range.each_with_index do |ipaddr,index|
            next if index < 4
            next if iprange_range.size == index
            iprange_array << ipaddr.to_s
          end
          iprange_array
        end
      end
    end
  end
end
