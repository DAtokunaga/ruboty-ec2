require 'ipaddr'

module Ruboty
  module Ec2
    module Helpers
      class Util
        def initialize(message, channel = nil)
          @channel = channel if !channel.nil?
          @msg = message
          check_channel
          check_command
        end

        def now
          Time.now.strftime("%Y/%m/%d %H:%M:%S.%L")
        end

        def exchange_rate
          x_rate = ENV["RUBOTY_EC2_EXCHANGE_RATE"]
          x_rate = 120.0 if x_rate.nil? or x_rate.to_f == 0
          x_rate.to_f
        end

        # 当月中の経過率
        def daily_rate_monthly
          now        = Time.now
          next_month = now + 32 * 24 * 60 * 60
          start_curr_month = Time.new(now.year, now.month)
          start_next_month = Time.new(next_month.year, next_month.month)
          (now - start_curr_month) / (start_next_month - start_curr_month)
        end

        def check_channel
          if channels = ENV['RUBOTY_EC2_CHANNELS']
            from_ch = get_channel
            raise "このチャンネルでは実行できないよ" if !channels.split(",").include?(from_ch)
          else
            raise "環境変数[RUBOTY_EC2_CHANNELS]の設定が足りないみたい。。"
          end
        end

        def check_command
          cmd_name = ""
          caller.each do |cl|
            next if cl.index("handlers").nil? or !cmd_name.empty?
            cmd_name = cl[/`([^']*)'/, 1]
          end
          from_ch  = get_channel

          # superadmins
          super_admin_env = ENV["RUBOTY_EC2_SUPER_ADMIN"]
          admins          = (super_admin_env.nil? ? [] : super_admin_env.split(","))

          # admins for each channels
          ch_admin_env    = ENV["RUBOTY_EC2_ADMIN_#{from_ch}"]
          ch_admin_env.split(",").each{|env| admins << env} if !ch_admin_env.nil?

          restrict_list  = ENV["RUBOTY_EC2_RESTRICT_CMD_#{from_ch}"] || ""
          return if restrict_list.empty?
          restrict_array = restrict_list.split(",")
          restrict_hash  = {}
          restrict_array.each do |rstrct|
            _rstrct   = rstrct.split(":")
            _cmd_name = _rstrct[0]
            _rstrct.shift
            restrict_hash[_cmd_name] = _rstrct + admins
          end
          if restrict_hash.include?(cmd_name)
            append_msg = "コマンド実行権限についての詳細は、 #{ENV['SLACK_USERNAME']} ec2 privilege list コマンドで確認できるよ"
            raise "#{cmd_name}コマンドを実行する権限がないよ\n#{append_msg}" if restrict_hash[cmd_name].empty?
            if !restrict_hash[cmd_name].include?(get_caller)
              raise "#{cmd_name}コマンドは#{restrict_hash[cmd_name]}だけが実行できるよ. 頼んでみてね\n#{append_msg}"
            end
          end
        end

        def get_privilege
          privileges = {:super_admin => [],
                        :channel_admin => {},
                        :restrict_command => {}}
          channels   = ENV['RUBOTY_EC2_CHANNELS'].split(",")

          # superadmins
          super_admin_str = ENV["RUBOTY_EC2_SUPER_ADMIN"] || ""
          super_admin_str.split(',').each do |super_admin|
            privileges[:super_admin] << super_admin
          end

          # admins for each channels
          channels.each do |ch|
            privileges[:channel_admin][ch] = []
            ch_admin_str = ENV["RUBOTY_EC2_ADMIN_#{ch}"] || ""
            ch_admin_str.split(',').each do |ch_admin|
              privileges[:channel_admin][ch] << ch_admin
            end
          end

          # allow command for each channels, each user
          channels.each do |ch|
            privileges[:restrict_command][ch] = {}
            restrict_list  = ENV["RUBOTY_EC2_RESTRICT_CMD_#{ch}"] || ""
            restrict_list.split(",").each do |rstrct|
              _rstrct   = rstrct.split(":")
              _cmd_name = _rstrct[0]
              _rstrct.shift
              privileges[:restrict_command][ch][_cmd_name] = _rstrct
            end
          end
          privileges
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

        def get_protocol
          'http://'
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

        def get_account_id
          from_ch    = get_channel
          account_id = ENV["RUBOTY_EC2_ACCOUNT_ID_#{from_ch}"]
          raise "環境変数[RUBOTY_EC2_ACCOUNT_ID_#{from_ch}]の設定が足りないみたい。。" if account_id.nil? or account_id.empty?
          account_id
        end

        def get_channel
          return @channel if !@channel.nil?
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

        def valid_ip?(ip_str)
          IPAddr.new(ip_str)
          true
        rescue => e
          false
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

        def get_time_diff(from_str, to_str = nil)
          to_str     = Time.now.to_s if to_str.nil?
          uptime_sec = Time.parse(to_str) - Time.parse(from_str)
          # 課金時間計算なので、1時間に満たないものも1と数える
          uptime_hour = (uptime_sec / 3600).to_i + 1
          return 0 if uptime_hour < 1
          uptime_hour
        end

      end
    end
  end
end

# AWSリソースのタグ名からハッシュのキー名の相互変換用Camel/Snakeケース変換処理
class String
  def snakecase
    s = self
    words = []
    until ( md = s.match( /[A-Z][a-z]*/ ) ).nil?
      words << md[0]
      s = md.post_match
    end
    words.collect { |word| word.downcase }.join( '_' )
  end
  def camelcase
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end
end

