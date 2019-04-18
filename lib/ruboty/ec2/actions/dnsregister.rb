module Ruboty
  module Ec2
    module Actions
      class Dnsregister < Ruboty::Actions::Base
        def call
          puts "ec2 dnsregister #{message[:resource]} called"
          resource = message[:resource]
          autostart if resource == "autostart"
          instance  if resource == "instance"
        end

        private

        def autostart
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          ## 現在利用中のインスタンス情報を取得
          # 2019SpeedUp filter条件にtag:AutoStartを追加(下で同じ値をチェックしてて冗長なのはスルーして)
          ins_infos = ec2.get_ins_infos({'AutoStart' => '*'})

          ## メイン処理 ##

          # 起動中の自動起動対象インスタンス取得
          start_ins_infos = {}
          ins_infos.each do |name, ins|
            next if ins[:state] != "running"
            next if !/10.[\d]+.0.4$/.match(ins[:private_ip]).nil?
            next if ins[:auto_start].nil? or ins[:auto_start].empty?
            start_ins_infos[name] = ins
          end
          if start_ins_infos.empty?
            message.reply("起動中の自動起動対象インスタンスが一つもないのでなにもしないよ.")
            return
          end

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_multi_public_ip(start_ins_infos.keys)

          # DNS設定/再設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          message.reply("起動中の自動起動対象インスタンスのDNS再設定が完了したよ.")
        rescue => e
          message.reply(e.message)
        end

        def instance
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]
          return if ins_name.nil?
          caller   = util.get_caller

          ## 事前チェック ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos = ec2.get_ins_infos({'Name' => ins_name})
          # 存在チェック
          raise "インスタンス[#{ins_name}]が見つからないよ." if ins_infos.empty?
          # ステータス[起動]チェック
          ins_info = ins_infos[ins_name]
          raise "インスタンス[#{ins_name}]は起動してないよ." if ins_info[:state] != "running"
          raise "インスタンス[#{ins_name}]は処理中でDNS再設定できないよ." if !/10.[\d]+.0.4$/.match(ins_info[:private_ip]).nil?

          ## メイン処理 ##

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_public_ip(ins_name)

          # DNS設定/再設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          reply_msg =  "DNS再設定が完了したよ[#{util.get_protocol(ins_pip_hash[ins_name][:version])}#{ins_name}.#{util.get_domain} => #{ins_pip_hash[ins_name][:public_ip]}]"
          reply_msg << "[管理 #{util.get_protocol(ins_pip_hash[ins_name][:version])}#{ins_name}#{Ruboty::Ec2::Const::AdminSuffix}.#{util.get_domain}]" if !ins_pip_hash[ins_name][:version].empty?
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

      end
    end
  end
end
