require "ruboty/ec2/helpers/util"
require "ruboty/ec2/helpers/brain"
require "ruboty/ec2/helpers/ec2"
require "ruboty/ec2/helpers/r53"
require "ruboty/ec2/actions/create"
require "ruboty/ec2/actions/stop"
require "ruboty/ec2/actions/start"
require "ruboty/ec2/actions/destroy"
require "ruboty/ec2/actions/list"
require "ruboty/ec2/actions/archive"
require "ruboty/ec2/actions/extract"
require "ruboty/ec2/actions/edit"
require "ruboty/ec2/actions/detail"
require "ruboty/ec2/actions/autostart"
require "ruboty/ec2/actions/autostop"
require "ruboty/ec2/actions/copy"
require "ruboty/ec2/actions/usage"
require "ruboty/ec2/actions/access"

module Ruboty
  module Handlers
    class Ec2 < Base
      # 自動起動／停止系
      on(/ec2 autostart (?<cmd>exec|list|add|del) *(?<ins_name>\S+)*\z/,
                                           name: 'autostart', description: 'manage auto-start instances')
      on(/ec2 autostop (?<cmd>exec|list|add|del) *(?<ins_name>\S+)*\z/,
                                           name: 'autostop',  description: 'manage auto-stop instances')

      # インスタンス操作系
      on(/ec2 create (?<ins_name>\S+) *(?<ami_id>\S+)*\z/,
                                           name: 'create',    description: 'create instance')
      on /ec2 stop (?<ins_name>\S+)\z/,    name: 'stop',      description: 'stop instance'
      on /ec2 start (?<ins_name>\S+)\z/,   name: 'start',     description: 'start instance'
      on /ec2 destroy (?<ins_name>\S+)\z/, name: 'destroy',   description: 'destroy instance'
      on /ec2 archive *(?<ins_name>\S+)*\z/, name: 'archive', description: 'archive instance'
      on /ec2 extract (?<ins_name>\S+)\z/, name: 'extract',   description: 'extract backed up instance'
      on /ec2 copy (?<from_arc>\S+) +(?<to_ins>\S+)\z/,
                                           name: 'copy',      description: 'copy instance'
      on /ec2 access (?<cmd>give|revoke) +(?<ins_name>\S+) *(?<sg_name>\S+)*\z/,
                                           name: 'access',    description: 'manage permitted source ip'

      # インスタンスメタ情報管理系
      on /ec2 detail (?<ins_name>\S+)\z/,  name: 'detail',    description: 'show instance/archive/AMI detail information'
      on(/ec2 list *((?<resource>instance|archive|ami)*|(?<resource>filter) +(?<word>\S+)+) *\z/,
                                           name: 'list',      description: 'show instance/archive/AMI list')
      on(/ec2 usage *(?<yyyymm>last|20\d{4}+)*\z/,
                                           name: 'usage',     description: 'show instance usage of specified month')
      on(/ec2 edit (?<tag_name>spec|desc|param) +(?<ins_name>\S+) +(?<data>.+)\z/m,
                                           name: 'edit',      description: 'edit data of spec, desc and param')

      def create(message)
        Ruboty::Ec2::Actions::Create.new(message).call
      end

      def stop(message)
        Ruboty::Ec2::Actions::Stop.new(message).call
      end

      def start(message)
        Ruboty::Ec2::Actions::Start.new(message).call
      end

      def destroy(message)
        Ruboty::Ec2::Actions::Destroy.new(message).call
      end

      def list(message)
        Ruboty::Ec2::Actions::List.new(message).call
      end

      def archive(message)
        Ruboty::Ec2::Actions::Archive.new(message).call
      end

      def extract(message)
        Ruboty::Ec2::Actions::Extract.new(message).call
      end

      def edit(message)
        Ruboty::Ec2::Actions::Edit.new(message).call
      end

      def detail(message)
        Ruboty::Ec2::Actions::Detail.new(message).call
      end

      def autostart(message)
        Ruboty::Ec2::Actions::Autostart.new(message).call
      end

      def autostop(message)
        Ruboty::Ec2::Actions::Autostop.new(message).call
      end

      def copy(message)
        Ruboty::Ec2::Actions::Copy.new(message).call
      end

      def access(message)
        Ruboty::Ec2::Actions::Access.new(message).call
      end

      def usage(message)
        Ruboty::Ec2::Actions::Usage.new(message).call
      end
    end
  end
end
