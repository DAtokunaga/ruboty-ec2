module Ruboty
  module Ec2
    module Actions
      class Permit < Ruboty::Actions::Base
        def call
          puts "ec2 permit #{message[:cmd]} called"
          cmd_name = message[:cmd]
          list if cmd_name == "list"
          add  if cmd_name == "add"
          del  if cmd_name == "del"
        end

        private

        def list
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          ## メイン処理 ##

          ## インスタンス／SG情報取得
          sg_infos  = ec2.get_sg_infos
          ins_infos = ec2.get_ins_infos

          msg_list  = ""
          sg_infos.sort {|(k1, v1), (k2, v2)| k1 <=> k2 }.each do |sg_name, sg_info|
            next if sg_name == "default"
            next if !sg_name.index("skt-").nil?
            msg_list << "\n[#{sg_name}]"
            msg_list << "\n  Permitted IPs  -> #{sg_info[:ip_perms].join(',')}"
            inuse_list = []
            ins_infos.each do |name, ins|
              inuse_list << name if ins[:groups].keys.include?(sg_name)
            end
            if inuse_list.empty?
              msg_list << "\n  Instance InUse -> なし"
            else
              msg_list << "\n  Instance InUse -> #{inuse_list.join(',')}"
            end
          end
          header_str = "アクセス許可ポリシー(対象ポート:443/8443)の情報だよ"
          reply_msg  = "#{header_str} ```#{msg_list}```"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def add
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          util = Ruboty::Ec2::Helpers::Util.new(message)

          # チャットコマンド情報取得
          sg_name  = message[:sg_name]
          ip_csv   = message[:ip_csv]
          return if sg_name.nil? or ip_csv.nil?

          ## 事前チェック ##

          # 作成可否チェック
          add_ng_sgs = ["any", "default"]
          if add_ng_sgs.include?(sg_name)
            raise "アクセス許可ポリシー[#{sg_name}]は作成も削除もできないよ"
          end

          # セキュリティグループ名チェック
          if !sg_name.match(/^[a-z0-9\-]+$/) or sg_name.length > 6
            warn_msg =  "アクセス許可ポリシー名は↓このルールで指定してね\n"
            warn_msg << "```\n"
            warn_msg << "  許容文字 -> 半角英数字(小文字)、及び-(半角ハイフン)\n"
            warn_msg << "  文字列長 -> 6文字以内"
            warn_msg << "```"
            raise warn_msg
          end

          # 指定されたSGの存在チェック
          sg_infos = ec2.get_sg_infos
          raise "既にアクセス許可ポリシー[#{sg_name}]は作成済みだよ" if sg_infos.keys.include?(sg_name)

          # IPアドレス形式チェック(ネットマスクがない場合は/32を追加してあげる)
          ip_array = []
          ip_csv.split(',').each do |ipaddr|
            raise "IPアドレス[#{ipaddr}]が間違っているよ" if !util.valid_ip?(ipaddr)
            if ipaddr.include?('/')
              ip_array << ipaddr
            else
              ip_array << "#{ipaddr}/32"
            end
          end

          ## メイン処理 ##

          # セキュリティグループ追加
          ec2.add_sg(sg_name, ip_array)
          reply_msg = "アクセス許可ポリシー[#{sg_name}]を追加したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end

        def del
          # AWSアクセス、その他ユーティリティのインスタンス化
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          sg_name  = message[:sg_name]
          return if sg_name.nil?

          ## 事前チェック ##

          # 削除可否チェック
          del_ng_sgs = ["any", "default"]
          if del_ng_sgs.include?(sg_name)
            raise "アクセス許可ポリシー[#{sg_name}]は作成も削除もできないよ"
          end

          # 指定されたSGの存在チェック
          sg_infos = ec2.get_sg_infos
          raise "アクセス許可ポリシー[#{sg_name}]が見つからないよ" if !sg_infos.keys.include?(sg_name)

          ins_infos = ec2.get_ins_infos
          ins_infos.each do |name, ins|
            if ins[:groups].keys.include?(sg_name)
              raise "アクセス許可ポリシー[#{sg_name}]はインスタンス[#{name}]が使用中だよ"
            end
          end

          ## メイン処理 ##

          # セキュリティグループ削除
          ec2.del_sg(sg_infos[sg_name][:group_id])
          reply_msg = "アクセス許可ポリシー[#{sg_name}]を削除したよ"
          message.reply(reply_msg)
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
