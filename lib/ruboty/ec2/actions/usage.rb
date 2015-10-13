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
              # Redis上の月別稼働時間累積値を更新
              brain.save_ins_uptime(name, uptime, yyyymm)
              # Redis上にins_type,os_typeを保存(インスタンス別料金算出で利用)
              brain.save_ins_type(name, ins[:instance_type], yyyymm)
              os_type = (!ins[:spec].nil? and ins[:spec].downcase.include?("rhel")) ? "rhel" : "centos"
              brain.save_os_type(name, os_type, yyyymm)

              # タグ[LastUsedTime]を今月頭の時刻で上書き
              params =  {"LastUsedTime" => cur_month_start}
              ec2.update_tags([ins[:instance_id]], params)
            end
          end

          # 起動中インスタンスの起動時間取得
          brain_infos = brain.get_ins_infos(yyyymm)
          # 今月指定(or 指定なし)の場合は、起動から現在までの時間を加算して表示（注．加算した結果はredisには保存しない）
          if cur_month == yyyymm
            ins_infos.each do |name, ins|
              next if ins[:state] != "running"
              last_used_time = ins[:last_used_time]
              next if last_used_time.nil?
              os_type = (!ins[:spec].nil? and ins[:spec].downcase.include?("rhel")) ? "rhel" : "centos"
              brain_infos[name] ||= {:uptime => 0}
              brain_infos[name][:uptime]    += util.get_time_diff(last_used_time)
              brain_infos[name][:os_type]  ||= os_type
              brain_infos[name][:ins_type] ||= ins[:instance_type]
            end
          end

          ins_price     = Ruboty::Ec2::Const::InsPrice
          ebs_price     = Ruboty::Ec2::Const::EbsPrice
          os_rate       = Ruboty::Ec2::Const::RhelCentPriceRate
          # EBS料金の日割り算出のため、当月の進捗率(経過日数/全日数)を取得
          daily_rate    = (cur_month == yyyymm ? util.daily_rate_monthly : 1.0)
          exchange_rate = util.exchange_rate

          reply_msg =  "インスタンス別に、稼働時間を集計して概算費用を計算してみたよ！\n```"
          reply_msg << "\n対象月[#{yyyymm}] 為替レート[#{exchange_rate}] 注）設定値のため実際の為替レートとは異なります"
          reply_msg << "\n- InsName ------| Uptime  * UnitPrice => Estimated Cost (USD & JPY)"
          brain_infos.sort {|(k1, v1), (k2, v2)| v2[:uptime] <=> v1[:uptime]}.each do |name, brain_info|
            uptime   = brain_info[:uptime]
            os_type  = brain_info[:os_type]
            ins_type = brain_info[:ins_type]

            # 指定月の稼働時間
            uptime_monthly = brain_info[:uptime]
            if ins_price[ins_type].nil?
              reply_msg << sprintf("\n%-15s | %4d Hr   ※タイプ[%s]の料金が未定義のため料金算出不可",
                                   name, uptime_monthly, ins_type)
              next
            end
            # インスタンスタイプから時間単価取得
            price_per_hour = ins_price[ins_type]
            # RHEL(有償AMI)の場合の割増処理
            price_per_hour = price_per_hour * os_rate if os_type == "rhel"
            # 指定月の課金額(EC2使用料＋EBS使用料) ※EBSは月末に満額となるよう日割り計算する
            charge_monthly_usd = (price_per_hour * uptime_monthly) + (ebs_price * daily_rate) 
            charge_monthly_jpy = (charge_monthly_usd * exchange_rate).ceil
            reply_msg << sprintf("\n%-15s | %4d Hr * %5.3f USD => %8.3f USD = %6d JPY ",
                                 name, uptime_monthly, price_per_hour, charge_monthly_usd, charge_monthly_jpy)
          end
          reply_msg << "```"
          if !brain_infos.empty?
            message.reply(reply_msg)
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
