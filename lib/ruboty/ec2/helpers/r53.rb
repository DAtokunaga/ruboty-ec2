require 'aws-sdk'

module Ruboty
  module Ec2
    module Helpers
      class Route53
        def initialize(message, channel = nil) 
          puts "Ruboty::Ec2::Helpers::Route53.initialize called"
          @util    = Util.new(message, channel)
          @domain  = @util.get_domain
          @r53     = ::Aws::Route53::Client.new(@util.get_aws_config)
          @zone_id = get_zone_id
          raise "Domainが間違っているよ" if @zone_id.nil?
        end

        def get_zone_id
          puts "Ruboty::Ec2::Helpers::Route53.get_zone_id called"
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
          puts "Ruboty::Ec2::Helpers::Route53.get_record_sets called"
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

        def update_record_sets(upd_infos)
          puts "Ruboty::Ec2::Helpers::Route53.update_record_sets called"
          upd_infos.each do |ins_name, public_ip|
            record_sets = []
            record_sets << {
              :action     => "UPSERT",
              :resource_record_set => {
                :name     => "#{ins_name}.#{@domain}",
                :type     => "A",
                :ttl      => 10,
                :resource_records => [{:value  => public_ip}]
              }
            }
            record_sets << {
              :action     => "UPSERT",
              :resource_record_set => {
                :name     => "#{ins_name}.#{@domain}",
                :type     => "MX",
                :ttl      => 10,
                :resource_records => [{
                  :value  => "10 #{ins_name}.#{@domain}."
                }]
              }
            }
            params = {
              :hosted_zone_id => @zone_id,
              :change_batch   => {
                :comment      => "for sakutto instance",
                :changes      => record_sets
              } 
            }
            @r53.change_resource_record_sets(params)
            # wait for AWS Route53 API
            sleep(Ruboty::Ec2::Const::WaitTimeForR53API)
          end
        end

        def delete_record_sets(del_infos)
          puts "Ruboty::Ec2::Helpers::Route53.delete_record_sets called"
          # check exist fqdn
          list_params = {
            :hosted_zone_id => @zone_id
          }
          flag = true
          # loop for getting all records by list_resorce_record_sets
          while flag do
            resp = @r53.list_resource_record_sets(list_params)
            resp.resource_record_sets.each do |rset|
              next if rset.type != "A"
              ins_name = rset.name.gsub(/\..*/, '')
#puts "ins_name = #{ins_name}"
              next if !del_infos.include?(ins_name)
              next if del_infos[ins_name].nil?
#puts "target instance [Name = #{ins_name}, Public = #{del_infos[ins_name]}]"
              record_sets = []
              record_sets << {
                :action     => "DELETE",
                :resource_record_set => {
                  :name     => "#{ins_name}.#{@domain}",
                  :type     => "A",
                  :ttl      => 10,
                  :resource_records => [{:value => del_infos[ins_name]}]
                }
              }
              record_sets << {
                :action     => "DELETE",
                :resource_record_set => {
                  :name     => "#{ins_name}.#{@domain}",
                  :type     => "MX",
                  :ttl      => 10,
                  :resource_records => [{:value => "10 #{ins_name}.#{@domain}"}]
                }
              }
              return if record_sets.empty?
              # delete record set
              params = {
                :hosted_zone_id => @zone_id,
                :change_batch   => {
                  :changes      => record_sets
                }
              }
              @r53.change_resource_record_sets(params)
              # wait for AWS Route53 API
              sleep(Ruboty::Ec2::Const::WaitTimeForR53API)
            end
#puts "resp.next_record_name = #{resp.next_record_name}"
#puts "resp.next_record_type = #{resp.next_record_type}"
            # check next loop?
            if resp.next_record_name.nil?
              flag = false
            else
              list_params[:start_record_name] = resp.next_record_name
              list_params[:start_record_type] = resp.next_record_type
            end
          end
        end

      end
    end
  end
end
