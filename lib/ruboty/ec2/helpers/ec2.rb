require 'aws-sdk'

module Ruboty
  module Ec2
    module Helpers
      class Ec2
        def initialize(message, channel = nil) 
          puts "Ruboty::Ec2::Helpers::Ec2.initialize called"
          @util      = Util.new(message, channel)
          @subnet_id = @util.get_subnet_id
          @ec2       = ::Aws::EC2::Client.new(@util.get_aws_config)
          raise "SubnetIDが間違っているよ" if !exist_subnet?(@subnet_id)
        end

        def exist_subnet?(subnet_id)
          puts "Ruboty::Ec2::Helpers::Ec2.exist_subnet? called"
          params = {:filters => [{:name => "subnet-id", values: [subnet_id]}]}
          resp   = @ec2.describe_subnets(params)
          resp.subnets.size > 0 ? true : false
        end

        def get_subnet_cidr(subnet_id)
          puts "Ruboty::Ec2::Helpers::Ec2.get_subnet_cidr called"
          params = {:filters => [{:name => "subnet-id", values: [subnet_id]}]}
          resp   = @ec2.describe_subnets(params)
          resp.subnets.first.cidr_block
        end

        def get_ins_infos(tag_filters = {})
          puts "Ruboty::Ec2::Helpers::Ec2.get_ins_infos called"
          params = {:filters => [{:name => "subnet-id", :values => [@subnet_id]}]}
          tag_filters.each do |tag_key, tag_value|
            params[:filters] << {:name => "tag:#{tag_key}", :values => [tag_value]}
          end

          resp      = @ec2.describe_instances(params)
          ins_infos = {}

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
              sg_infos = {}
              ins.security_groups.each do |sg|
                sg_infos[sg.group_name] = sg.group_id
              end
              ins_info[:groups]        = sg_infos
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

        def get_arc_infos(tag_filters = {})
          puts "Ruboty::Ec2::Helpers::Ec2.get_arc_infos called"
          params = {:filters => [{:name => "is-public", values: ["false"]}]}
          tag_filters.each do |tag_key, tag_value|
            params[:filters] << {:name => "tag:#{tag_key}", :values => [tag_value]}
          end

puts "describe_images start"
          resp      = @ec2.describe_images(params)
          ami_infos = {}
puts "describe_images end"

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
puts "create arc_infos: #{name}"
          end
puts "create arc_infos end"
          ami_infos
        end

        def get_ami_infos
          puts "Ruboty::Ec2::Helpers::Ec2.get_ami_infos called"
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
          puts "Ruboty::Ec2::Helpers::Ec2.create_ins called"
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
          puts "Ruboty::Ec2::Helpers::Ec2.stop_ins called"
          params = {:instance_ids => ins_ids}
          @ec2.stop_instances(params)
        end

        def start_ins(ins_ids)
          puts "Ruboty::Ec2::Helpers::Ec2.start_ins called"
          params = {:instance_ids => ins_ids}
          @ec2.start_instances(params)
        end

        def destroy_ins(ins_id)
          puts "Ruboty::Ec2::Helpers::Ec2.destroy_ins called"
          params = {:instance_ids => [ins_id]}
          @ec2.terminate_instances(params)
        end

        def update_tags(ins_ids, tag_hash)
          puts "Ruboty::Ec2::Helpers::Ec2.update_tags called"
          # リトライ回数
          cnt_retry = 0

          params = {:resources => ins_ids, :tags => []}
          tag_hash.each do |key,val|
            params[:tags] << {:key => key, :value => val}
          end
          @ec2.create_tags(params)
        rescue
          cnt_retry += 1
          # 3 times retry
          retry if cnt_retry < 4
        end

        def delete_tags(ins_ids, tag_keys)
          puts "Ruboty::Ec2::Helpers::Ec2.delete_tags called"
          params = {:resources => ins_ids, :tags => []}
          tag_keys.each do |key|
            params[:tags] << {:key => key}
          end
          @ec2.delete_tags(params)
        end

        def wait_for_associate_public_ip(ins_name)
          puts "Ruboty::Ec2::Helpers::Ec2.wait_for_associate_public_ip called"
          started_at = Time.now
          public_ip  = nil
          puts "  associate public ip check start"
          while public_ip.nil? do
            sleep(3)
            ins_info  = get_ins_infos({'Name' => ins_name})
            public_ip = ins_info[ins_name][:public_ip] if !ins_info[ins_name].nil?
            elpsd_sec = (Time.now - started_at).to_i
            puts "    ... #{elpsd_sec} seconds elapsed"
            break if ins_info.empty? or (Time.now - started_at).to_i > 90
          end
          raise "インスタンス[#{ins_name}]が正常に起動しないよー。。(´Д⊂ｸﾞｽﾝ" if public_ip.nil?
          puts "  associate public ip OK [#{public_ip}]"
          public_ip
        end

        def wait_for_associate_multi_public_ip(ins_names)
          puts "Ruboty::Ec2::Helpers::Ec2.wait_for_associate_multi_public_ip called"
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
            break if (Time.now - started_at).to_i > 90
          end
          if ins_count != ins_pip_hash.size
            raise "インスタンス#{ins_names-ins_pip_hash.keys}が正常に起動しないよー。。(´Д⊂ｸﾞｽﾝ"
          end
          ins_pip_hash
        end

        def create_ami(ins_id, ins_name)
          puts "Ruboty::Ec2::Helpers::Ec2.create_ami called"
          ami_name = "#{ins_name}_#{Time.now.strftime('%Y%m%d%H%M%S')}"
          params   = {:instance_id => ins_id, :no_reboot => true, :name => ami_name}
          ami      = @ec2.create_image(params)
          ami_id   = ami[:image_id]
        end

        def wait_for_create_multi_ami(ami_names)
          puts "Ruboty::Ec2::Helpers::Ec2.wait_for_create_multi_ami called"
          started_at  = Time.now
          ami_count   = ami_names.size
          ami_id_hash = {}
          while ami_count != ami_id_hash.size do
            sleep(60)
            ami_infos = get_arc_infos
            ami_infos.each do |name, ami_info|
              next if !ami_names.include?(name)
              added_flag = ami_id_hash[name].nil?
              if ami_info[:state] == "available"
                ami_id_hash[name] = ami_info
              end
              if added_flag and !ami_id_hash[name].nil?
                puts "　アーカイブ[#{ami_info[:name]}]作成完了！"
              end
            end
            break if (Time.now - started_at).to_i > 1800
          end
          if ami_count != ami_id_hash.size
            raise "インスタンス#{ami_names-ami_id_hash.keys}のアーカイブ化に失敗したよー。。(´Д⊂ｸﾞｽﾝ"
          end
          ami_id_hash
        end

        def destroy_ami(arc_id, snapshot_id)
          puts "Ruboty::Ec2::Helpers::Ec2.destroy_ami called"
          @ec2.deregister_image(image_id: arc_id)
          @ec2.delete_snapshot(snapshot_id: snapshot_id)
        end

        def get_vpc_id
          puts "Ruboty::Ec2::Helpers::Ec2.get_vpc_id called"
          params = {:filters => [{:name => "subnet-id", values: [@subnet_id]}]}
          resp   = @ec2.describe_subnets(params)
          resp.subnets.first.vpc_id
        end

        def get_sg_infos
          puts "Ruboty::Ec2::Helpers::Ec2.get_sg_infos called"
          params   = {:filters => [{:name => "vpc-id", values: [get_vpc_id]}]}
          resp     = @ec2.describe_security_groups(params)
          sg_infos = {}
          resp.security_groups.each do |sg|
            sg_info = {}
            sg_name = sg.group_name 
            sg_info[:group_name] = sg_name
            sg_info[:group_id]   = sg.group_id
            ip_perms = []
            sg.ip_permissions.each do |perm|
              next if perm.from_port != 443
              next if perm.to_port   != 443
              perm.ip_ranges.each do |range|
                ip_perms << range.cidr_ip
              end
            end
            sg_info[:ip_perms] = ip_perms
            sg_infos[sg_name]  = sg_info
          end
          sg_infos
        end

        def add_sg(sg_name, ip_ranges)
          # セキュリティグループ作成(許可IP追加は別途実施)
          params = {:vpc_id      => get_vpc_id,
                    :group_name  => sg_name,
                    :description => sg_name}
          resp   = @ec2.create_security_group(params)
          sg_id  = resp.group_id

          # 作成したセキュリティグループに許可IPを追加
          add_ip_ranges = []
          ip_ranges.each do |ip_range|
            add_ip_ranges << {:cidr_ip => ip_range}
          end
          params = {
            :group_id => sg_id,
            :ip_permissions => [
              {
                :ip_protocol => 'tcp',
                :ip_ranges   => add_ip_ranges,
                :from_port   => 443,
                :to_port     => 443
              },
              {
                :ip_protocol => 'tcp',
                :ip_ranges   => add_ip_ranges,
                :from_port   => 8443,
                :to_port     => 8443
              },
            ]
          }
          @ec2.authorize_security_group_ingress(params)
        end

        def del_sg(sg_id)
          # セキュリティグループ削除
          params = {:group_id => sg_id}
          @ec2.delete_security_group(params)
        end

        def update_groups(ins_id, sg_ids)
          puts "Ruboty::Ec2::Helpers::Ec2.update_groups called"
          params   = {:instance_id => ins_id, :groups => sg_ids}
          @ec2.modify_instance_attribute(params)
        end   

        def add_permission(ami_id, account_id)
          puts "Ruboty::Ec2::Helpers::Ec2.add_permission called"
          params   = {:image_id => ami_id,
                      :attribute => "launchPermission",
                      :operation_type => "add",
                      :user_ids => [account_id]}
          @ec2.modify_image_attribute(params)
        end

        def delete_permission(ami_id, account_id)
          puts "Ruboty::Ec2::Helpers::Ec2.delete_permission called"
          params   = {:image_id => ami_id,
                      :attribute => "launchPermission",
                      :operation_type => "remove",
                      :user_ids => [account_id]}
          @ec2.modify_image_attribute(params)
        end

      end
    end
  end
end
