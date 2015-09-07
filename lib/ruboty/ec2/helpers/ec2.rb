require 'aws-sdk'

module Ruboty
  module Ec2
    module Helpers
      class Ec2
        def initialize(message) 
          @util      = Util.new(message)
          @subnet_id = @util.get_subnet_id
          @ec2       = ::Aws::EC2::Client.new(@util.get_aws_config)
          raise "SubnetIDが間違っているよ" if !exist_subnet?(@subnet_id)
        end

        def exist_subnet?(subnet_id)
          params = {:filters => [{:name => "subnet-id", values: [subnet_id]}]}
          resp   = @ec2.describe_subnets(params)
          resp.subnets.size > 0 ? true : false
        end

        def get_subnet_cidr(subnet_id)
          params = {:filters => [{:name => "subnet-id", values: [subnet_id]}]}
          resp   = @ec2.describe_subnets(params)
          resp.subnets.first.cidr_block
        end

        def get_ins_infos(ins_name = nil)
          filter_str = {:filters => [{:name => "tag:Name", :values => [ins_name]}]}
          params     = (ins_name ? filter_str : {})
          resp       = @ec2.describe_instances(params)
          ins_infos  = {}

          resp.reservations.each do |reservation|
            reservation.instances.each do |ins|
              next if ins.state.name == "terminated"
              ins_info                 = {}
              ins_info[:instance_id]   = ins.instance_id
              ins_info[:image_id]      = ins.image_id
              ins_info[:key_name]      = ins.key_name
              ins_info[:instance_type] = ins.instance_type
              ins_info[:launch_time]   = ins.launch_time
              ins_info[:virtual_type]  = ins.virtualization_type
              ins_info[:subnet_id]     = ins.subnet_id
              ins_info[:state]         = ins.state.name
              ins_info[:state_mark]    = @util.get_state_mark(ins.state.name)
              ins_info[:vpc_id]        = ins.vpc_id
              ins_info[:private_ip]    = ins.private_ip_address
              ins_info[:public_ip]     = ins.public_ip_address
              ins.tags.each do |tag|
                next if tag.value.empty?
                ins_info[tag.key.snakecase.to_sym] = tag.value
              end
              name = ins_info[:name] ? ins_info[:name] : ins_info[:instance_id]
              ins_infos[name] = ins_info
            end
          end
          ins_infos
        end

        def get_arc_infos(ins_name = nil)
          params    = {:filters => [{:name => "is-public", values: ["false"]}]}
          if !ins_name.nil?
            params[:filters] << {:name => "tag:Name", :values => [ins_name]}
          end
          resp      = @ec2.describe_images(params)
          ami_infos = {}

          resp.images.each do |ami|
            next if ami.state == "deregistered"
            ami_info            = {}
            ami.tags.each do |tag|
              ami_info[tag.key.snakecase.to_sym] = tag.value
            end
            # Owner, IpAddrタグありをArchive対象とする
            next if ami_info[:owner].nil?   or ami_info[:owner].empty?
            next if ami_info[:ip_addr].nil? or ami_info[:ip_addr].empty?
            ami_info[:image_id]     = ami.image_id
            ami_info[:virtual_type] = ami.virtualization_type
            ami_info[:snapshot_id]  = ami.block_device_mappings.first.ebs.snapshot_id
            ami_info[:ami_name]     = ami.name
            ami_info[:state]        = ami.state
            name                    = ami_info[:name] ? ami_info[:name] : ami_info[:ami_name]
            ami_infos[name]         = ami_info
          end
          ami_infos
        end

        def get_ami_infos
          params    = {:filters => [{:name => "is-public", values: ["false"]}]}
          resp      = @ec2.describe_images(params)
          ami_infos = {}

          resp.images.each do |ami|
            next if ami.state == "deregistered"
            ami_info = {}
            ami_id   = ami.image_id
            ami.tags.each do |tag|
              ami_info[tag.key.snakecase.to_sym] = tag.value
            end
            # Owner, IpAddrタグなし、Spec/DescタグありをAMI対象とする
            next if !ami_info[:owner].nil?   and !ami_info[:owner].empty?
            next if !ami_info[:ip_addr].nil? and !ami_info[:ip_addr].empty?
            next if ami_info[:desc].nil?     or  ami_info[:desc].empty?
            next if ami_info[:spec].nil?     or  ami_info[:spec].empty?
            ami_info[:image_id]     = ami_id
            ami_info[:virtual_type] = ami.virtualization_type
            ami_info[:snapshot_id]  = ami.block_device_mappings.first.ebs.snapshot_id
            ami_info[:name]         = ami.name
            ami_info[:state]        = ami.state
            ami_infos[ami_id]        = ami_info
          end
          ami_infos
        end

        def create_ins(_params)
          params = {
            :image_id => _params[:image_id],
            :min_count => 1, :max_count => 1,
            :key_name => Ruboty::Ec2::Const::KeyName,
            :instance_type => _params[:instance_type],
            :block_device_mappings => [{
              :device_name => "/dev/sda1",
              :ebs => {:volume_type => Ruboty::Ec2::Const::VolType}
            }],
            :network_interfaces => [{
              :device_index => 0,
              :subnet_id => @subnet_id,
              :associate_public_ip_address => true,
              :private_ip_address => _params[:private_ip_address]
            }],
            :monitoring => {:enabled => false},
            :iam_instance_profile => {:name => Ruboty::Ec2::Const::IamRole}
          }
          resp   = @ec2.run_instances(params).first
          ins    = resp[:instances].first
          ins_id = ins[:instance_id]
        end

        def stop_ins(ins_ids)
          params = {:instance_ids => ins_ids}
          @ec2.stop_instances(params)
        end

        def start_ins(ins_ids)
          params = {:instance_ids => ins_ids}
          @ec2.start_instances(params)
        end

        def destroy_ins(ins_id)
          params = {:instance_ids => [ins_id]}
          @ec2.terminate_instances(params)
        end

        def update_tags(ins_ids, tag_hash)
          params = {:resources => ins_ids, :tags => []}
          tag_hash.each do |key,val|
            params[:tags] << {:key => key, :value => val}
          end
          @ec2.create_tags(params)
        end

        def delete_tags(ins_ids, tag_keys)
          params = {:resources => ins_ids, :tags => []}
          tag_keys.each do |key|
            params[:tags] << {:key => key}
          end
          @ec2.delete_tags(params)
        end

        def wait_for_associate_public_ip(ins_name)
          started_at = Time.now
          public_ip  = nil
          while public_ip.nil? do
            sleep(1)
            ins_info  = get_ins_infos(ins_name)
            public_ip = ins_info[ins_name][:public_ip] if !ins_info[ins_name].nil?
            break if ins_info.empty? or (Time.now - started_at).to_i > 60
          end
          raise "インスタンス[#{ins_name}]が正常に起動しないよー。。(´Д⊂ｸﾞｽﾝ" if public_ip.nil?
          public_ip
        end

        def wait_for_associate_multi_public_ip(ins_names)
          started_at = Time.now
          ins_count = ins_names.size
          ins_pip_hash = {}
          while ins_count != ins_pip_hash.size do
            sleep(1)
            ins_infos = get_ins_infos
            ins_infos.each do |name, ins|
              next if !ins_names.include?(name)
              ins_pip_hash[name] = ins[:public_ip] if !ins[:public_ip].nil?
            end
            break if (Time.now - started_at).to_i > 60
          end
          if ins_count != ins_pip_hash.size
            raise "インスタンス#{ins_names-ins_pip_hash.keys}が正常に起動しないよー。。(´Д⊂ｸﾞｽﾝ"
          end
          ins_pip_hash
        end

        def create_ami(ins_id, ins_name)
          ami_name = "#{ins_name}_#{Time.now.strftime('%Y%m%d%H%M%S')}"
          params   = {:instance_id => ins_id, :name => ami_name}
          ami      = @ec2.create_image(params)
          ami_id   = ami[:image_id]
        end

        def destroy_ami(arc_id, snapshot_id)
          @ec2.deregister_image(image_id: arc_id)
          @ec2.delete_snapshot(snapshot_id: snapshot_id)
        end

      end
    end
  end
end
