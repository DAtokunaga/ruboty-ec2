require 'aws-sdk'

module Ruboty
  module Ec2
    module Helpers
      class Route53
        def initialize(message) 
          @util    = Util.new(message)
          @domain  = @util.get_domain
          @r53     = ::Aws::Route53::Client.new(@util.get_aws_config)
          @zone_id = get_zone_id
          raise "Domainが間違っているよ" if @zone_id.nil?
        end

        def get_zone_id
          zone_id = nil
          zones = @r53.list_hosted_zones[:hosted_zones]
          zones.each do |zone|
            zone_name = zone[:name]
            if !"#{@domain}.".index(zone_name).nil?
              zone_id = zone[:id].gsub(/.*\//, '')
            end
          end
          zone_id
        end

        def get_record_sets
          params       = {:hosted_zone_id => @zone_id}
          record_sets  = @r53.list_resource_record_sets(params)[:resource_record_sets]
          rset_infos = {}

          record_sets.each do |rset|
            next if rset.type != "A"
            host = rset.name.gsub(/\..*/, '')
            rset_info = {}
            rset_info[:host]      = host
            rset_info[:name]      = rset.name
            rset_info[:ttl]       = rset.ttl
            rset_info[:type]      = rset.type
            rset_info[:public_ip] = rset.resource_records.first.value if rset.resource_records.size > 0
            rset_infos[host]      = rset_info
          end
          rset_infos
        end

        def update_record_sets(ins_name, public_ip)
          params = {
            :hosted_zone_id => @zone_id,
            :change_batch   => {
              :comment      => "for ins_name",
              :changes      => [{
                :action     => "UPSERT",
                :resource_record_set => {
                  :name     => "#{ins_name}.#{@domain}",
                  :type     => "A",
                  :ttl      => 60,
                  :resource_records => [{
                    :value  => public_ip
                  }]
                }
              }]
            } 
          }
          @r53.change_resource_record_sets(params)
        end

      end
    end
  end
end
