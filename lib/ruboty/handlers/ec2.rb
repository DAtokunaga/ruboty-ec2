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
require "ruboty/ec2/actions/desc"
require "ruboty/ec2/actions/spec"
require "ruboty/ec2/actions/param"
require "ruboty/ec2/actions/autostart"
require "ruboty/ec2/actions/dontstop"
require "ruboty/ec2/actions/copy"

module Ruboty
  module Handlers
    class Ec2 < Base
      # 自動起動／停止系
      on(/ec2 autostart (?<cmd>exec|list|add|del) +(?<ins_name>\S+)\z/,
                                           name: 'autostart', description: 'manage auto-start instances')
      on(/ec2 dontstop (?<cmd>exec|list|add|del) +(?<ins_name>\S+)\z/,
                                           name: 'dontstop',  description: 'manage auto-stop instances')

      # インスタンス操作系
      on(/ec2 create (?<ins_name>\S+) *(?<ami_id>\S+)*\z/,
                                           name: 'create',    description: 'create instance')
      on /ec2 stop (?<ins_name>\S+)\z/,    name: 'stop',      description: 'stop instance'
      on /ec2 start (?<ins_name>\S+)\z/,   name: 'start',     description: 'start instance'
      on /ec2 destroy (?<ins_name>\S+)\z/, name: 'destroy',   description: 'destroy instance'
      on /ec2 archive (?<ins_name>\S+)\z/, name: 'archive',   description: 'archive instance'
      on /ec2 extract (?<ins_name>\S+)\z/, name: 'extract',   description: 'extract backed up instance'
      on /ec2 copy (?<from_ins>\S+) +(?<to_ins>\S+)\z/,
                                           name: 'copy',      description: 'copy instance'

      # インスタンスメタ情報管理系
      on /ec2 list *(?<resource>\S+)*\z/,  name: 'list',      description: 'show list of instance, archive and AMI'
      on /ec2 desc (?<ins_name>\S+)\z/,    name: 'desc',      description: 'show instance description'
      on /ec2 spec (?<ins_name>\S+)\z/,    name: 'spec',      description: 'show instance spec'
      on /ec2 param (?<ins_name>\S+)\z/,   name: 'param',     description: 'show instance param'
      on(/ec2 edit (?<tag>spec|desc|param) +(?<ins_name>\S+) +(?<data>.+)\z/,
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

      def desc(message)
        Ruboty::Ec2::Actions::Desc.new(message).call
      end

      def spec(message)
        Ruboty::Ec2::Actions::Spec.new(message).call
      end

      def param(message)
        Ruboty::Ec2::Actions::Param.new(message).call
      end

      def autostart(message)
        Ruboty::Ec2::Actions::Autostart.new(message).call
      end

      def dontstop(message)
        Ruboty::Ec2::Actions::Dontstop.new(message).call
      end

      def copy(message)
        Ruboty::Ec2::Actions::Copy.new(message).call
      end
    end
  end
end
