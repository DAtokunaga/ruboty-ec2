module Ruboty
  module Ec2
    module Actions
      class Usage < Ruboty::Actions::Base
        def call
          usage
        end

        private

        def usage
          # AWSアクセス、その他ユーティリティのインスタンス化
          util  = Ruboty::Ec2::Helpers::Util.new(message)
          ec2   = Ruboty::Ec2::Helpers::Ec2.new(message)
          brain = Ruboty::Ec2::Helpers::Brain.new(message)

          # チャットコマンド情報あから対象月を取得
          now       = Time.now
          cur_month = now.strftime("%Y%m")
          yyyymm    = (message[:yyyymm].nil? ? cur_month : message[:yyyymm])
          # last指定時は前月を設定
          yyyymm = Time.new(now.year, now.month-1).strftime("%Y%m") if yyyymm == "last"

          ## メイン処理 ##

          ## 現在利用中のインスタンス情報を取得
          ins_infos   = ec2.get_ins_infos

          usage_infos = {}

          if message[:yyyymm] == "last"
            # 引数がlast、起動中、最終利用時刻が前月、の３条件に合致するものは
            # 前月稼働時刻を設定しタグ[LastUsedTiem]に今月始めの時刻を登録する
            #  -> 常時起動や、月またぎインスタンスの時間計算契機がないので救済措置
            #  -> 毎月1日0時にruboty-cronでlast指定実行を登録する必要がある
            ins_infos.each do |name, ins|
              last_used_time = ins[:last_used_time]
              next if last_used_time.nil? or last_used_time.gsub(/-/,'').index(yyyymm).nil?
              next if ins[:state] != "running"

              cur_month_start = Time.new(now.year, now.month).to_s
              uptime  = util.get_time_diff(last_used_time, cur_month_start)
              brain.save_ins_uptime(name, uptime, yyyymm)

              # タグ[LastUsedTime]を今月頭の時刻で上書き
              params =  {"LastUsedTime" => cur_month_start}
              ec2.update_tags([ins[:instance_id]], params)
            end
          end

          # 起動中インスタンスの起動時間取得
          brain_infos = brain.get_ins_uptime(yyyymm)
          # 今月指定(or 指定なし)の場合は、起動から現在までの時間を加算して表示（注．redisには保存しない）
          if cur_month == yyyymm
            ins_infos.each do |name, ins|
              next if ins[:state] != "running"
              last_used_time = ins[:last_used_time]
              next if last_used_time.nil?
              brain_infos[name] ||= 0
              brain_infos[name] += util.get_time_diff(last_used_time)
            end
          end

          reply_msg = "インスタンス別稼働時間を集計したよ！\n対象月[#{yyyymm}]\n"
          brain_infos.sort {|(k1, v1), (k2, v2)| v2 <=> v1}.each do |name, uptime|
            reply_msg << sprintf("%4d h => %s\n", uptime, name)
          end
          if !brain_infos.empty?
            message.reply(reply_msg, code: true)
          else
            message.reply("対象月[#{yyyymm}]に稼働したインスタンスはないよ")
          end
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
