module Ruboty
  module Ec2
    module Actions
      class Extract < Ruboty::Actions::Base
        def call
          puts "ec2 extract called"
          extract
        end

        private

        def extract
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)

          # チャットコマンド情報取得
          ins_name = message[:ins_name]

          ## 事前チェック ##

          ## 現在利用中のアーカイブ情報を取得
          # 2019SpeedUp filter条件に対象インスタンス名を追加
          arc_infos = ec2.get_arc_infos({'Name' => ins_name})
          # アーカイブ存在チェック
          raise "アーカイブ[#{ins_name}]が見つからないよ" if !arc_infos.include?(ins_name)
          # ステータス[available]チェック
          arc_info = arc_infos[ins_name]
          raise "アーカイブ[#{ins_name}]は作成中だよ. もう少し待っててね" if arc_info[:state] == "pending"
          raise "アーカイブ[#{ins_name}]は今処理中で使えないっす..." if arc_info[:state] != "available"
          if !arc_info[:frozen].nil? and !arc_info[:frozen].empty?
            raise "アーカイブ[#{ins_name}]は凍結されてるよ. 先に解除(thaw)してね"
          end

          ## メイン処理 ##

          ## 現在利用中のインスタンス／AMIの情報を取得
          # 2019SpeedUp filter条件に対象インスタンス名を追加   
          ins_infos = ec2.get_ins_infos({'Name' => ins_name})

          # 作成するインスタンスタイプ判定（HVM or PVにより変わります）
          ins_type = (arc_info[:virtual_type] == "hvm" ?
                      Ruboty::Ec2::Const::InsTypeHVM :
                      Ruboty::Ec2::Const::InsTypePV)

          # インスタンス作成
          params = {:image_id => arc_info[:image_id], :private_ip_address => arc_info[:ip_addr],
                    :instance_type => ins_type}
          ins_id = ec2.create_ins(params)
          # タグ付け
          params =  {"Name"  => ins_name, "Owner" => arc_info[:owner],
                     "LastUsedTime" => Time.now.to_s, "ParentId" => arc_info[:parent_id]}
          params["Spec"]       = arc_info[:spec]  if !arc_info[:spec].nil?
          params["Desc"]       = arc_info[:desc]  if !arc_info[:desc].nil?
          params["Param"]      = arc_info[:param] if !arc_info[:param].nil?
          params["AutoStart"]  = arc_info[:auto_start] if !arc_info[:auto_start].nil?
          params["ExceptStop"] = arc_info[:except_stop] if !arc_info[:except_stop].nil?
          params["Version"]    = arc_info[:version] if !arc_info[:version].nil?
          ec2.update_tags([ins_id], params)

          # メッセージ置換・整形＆インスタンス作成した旨応答
          message.reply("アーカイブ[#{ins_name}]からインスタンスを作ったよ. DNS設定完了までもう少し待っててね")

          # パブリックIPを取得
          ins_pip_hash = ec2.wait_for_associate_public_ip(ins_name)

          # DNS設定
          r53 = Ruboty::Ec2::Helpers::Route53.new(message)
          r53.update_record_sets(ins_pip_hash)
          reply_msg =  "DNS設定が完了したよ[#{util.get_protocol(ins_pip_hash[ins_name][:version])}#{ins_name}.#{util.get_domain} => #{ins_pip_hash[ins_name][:public_ip]}]"
          reply_msg << "[管理 #{util.get_protocol(ins_pip_hash[ins_name][:version])}#{ins_name}#{Ruboty::Ec2::Const::AdminSuffix}.#{util.get_domain}]" if !ins_pip_hash[ins_name][:version].empty?
          message.reply(reply_msg)

          # アーカイブ削除
          ec2.destroy_ami(arc_info[:image_id], arc_info[:snapshot_id])
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
