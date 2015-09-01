require 'time'

module Ruboty
  module Ec2
    module Helpers
      class Brain
        NAMESPACE = 'ec2'
        def initialize(message)
          @msg   = message
          @brain = message.robot.brain.data[NAMESPACE] ||= {}
        end

        def save_ins_uptime(ins_name, uptime)
          yyyymm = Time.now.strftime('%Y%m')
          @brain[ins_name] ||= {:uptime => {}}
          @brain[ins_name][:uptime][yyyymm] ||= 0
          @brain[ins_name][:uptime][yyyymm] += uptime
p @brain
        end

        def get_ins_uptime(yyyymm = nil)
          yyyymm     = Time.now.strftime('%Y%m') if yyyymm.nil?
          ins_uptime = {}
          @brain.each do |ins_name, ins_data|
            uptime_hash = ins_data[:uptime]
            next if uptime_hash.nil?
            next if uptime_hash[yyyymm].nil?
            ins_uptime << {ins_name => uptime_hash[yyyymm]}
          end
          ins_uptime
        end

        def calc_uptime(from_str, to_str = nil)
          to_str     = Time.now.to_s if to_str.nil?
          uptime_sec = Time.parse(to_str) - Time.parse(from_str)
          # 月単位のため750以上になった場合は異常値としてスキップ
          return 0 if uptime_sec < 1 or uptime_sec > 750
          # 課金時間計算なので、1時間に満たないものも1と数える
          uptime_hour = (uptime_sec / 3600).to_i + 1
        end

      end
    end
  end
end

