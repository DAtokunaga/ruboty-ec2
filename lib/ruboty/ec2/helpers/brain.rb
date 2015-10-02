require 'time'

module Ruboty
  module Ec2
    module Helpers
      class Brain
        NAMESPACE = 'ec2'
        def initialize(message)
          @channel = Util.new(message).get_channel
          message.robot.brain.data[NAMESPACE] ||= {}
          @brain   = message.robot.brain.data[NAMESPACE][@channel] ||= {}
        end

        def save_ins_uptime(ins_name, uptime, yyyymm = nil)
          yyyymm = Time.now.strftime('%Y%m') if yyyymm.nil?
          @brain[ins_name] ||= {:uptime => {}}
          @brain[ins_name][:uptime][yyyymm] ||= 0
          @brain[ins_name][:uptime][yyyymm] += uptime
        end

        def get_ins_uptime(yyyymm)
          ins_uptime = {}
          @brain.each do |ins_name, ins_data|
            uptime_hash = ins_data[:uptime]
            next if uptime_hash.nil?
            next if uptime_hash[yyyymm].nil?
            ins_uptime[ins_name] = uptime_hash[yyyymm]
          end
          ins_uptime
        end

      end
    end
  end
end

