require 'ipaddr'

module Ruboty
  module Ec2
    module Helpers
      class Util
        def initialize(message)
          @msg = message
          check_channel
        end

        def now
          Time.now.strftime("%Y/%m/%d %H:%M:%S.%L")
        end

        def check_channel
          if channels = ENV['RUBOTY_EC2_CHANNELS']
            from_ch = get_channel
            raise "このチャンネルでは実行できないよ" if !channels.split(",").include?(from_ch)
          else
            raise "環境変数[RUBOTY_EC2_CHANNELS]の設定が足りないみたい。。"
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
          raise "環境変数[RUBOTY_EC2_DOMAIN_#{from_ch}]の設定が足りないみたい。。" if domain.nil? or domain.empty?
          domain
        end

        def get_default_ami
          from_ch   = get_channel
          ami_id    = ENV["RUBOTY_EC2_DEFAULT_AMI_#{from_ch}"]
          raise "環境変数[RUBOTY_EC2_DEFAULT_AMI_#{from_ch}]の設定が足りないみたい。。" if ami_id.nil? or ami_id.empty?
          ami_id
        end

        def get_subnet_id
          from_ch   = get_channel
          subnet_id = ENV["RUBOTY_EC2_SUBNET_ID_#{from_ch}"]
          raise "環境変数[RUBOTY_EC2_SUBNET_ID_#{from_ch}]の設定が足りないみたい。。" if subnet_id.nil? or subnet_id.empty?
          subnet_id
        end

        def get_channel
          @msg.original[:from] ? @msg.original[:from].split("@").first : "shell"
        end

        def get_caller
          @msg.original[:from] ? @msg.original[:from].split("/").last : "shell"
        end

        def usable_iprange(subnet_cidr)
          iprange_array = []
          iprange_range = IPAddr.new(subnet_cidr).to_range
          iprange_range.each_with_index do |ipaddr,index|
            next if index < 4
            iprange_array << ipaddr.to_s
          end
          iprange_array.pop
          iprange_array
        end

        def get_state_mark(_state)
          case _state
            when "pending"       then state = "\u{25B2}"
            when "running"       then state = "\u{25BA}"
            when "shutting-down" then state = "\u{25BC}"
            when "terminated"    then state = "\u{271D}"
            when "stopping"      then state = "\u{25BC}"
            when "stopped"       then state = "\u{25A0}"
            else state = "\u{203C}"
          end
          state
        end

      end
    end
  end
end

# AWSリソースのタグ名からハッシュのキー名に変換するためのスネークケース変換処理
class String
  def snakecase()
    s = self
    words = []
    until ( md = s.match( /[A-Z][a-z]*/ ) ).nil?
      words << md[0]
      s = md.post_match
    end
    words.collect { |word| word.downcase }.join( '_' )
  end
end

