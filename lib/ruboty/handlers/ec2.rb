require "ruboty/ec2/helpers/util"
require "ruboty/ec2/helpers/brain"
require "ruboty/ec2/helpers/ec2"
require "ruboty/ec2/helpers/r53"
require "ruboty/ec2/helpers/slack"
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
require "ruboty/ec2/actions/rename"
require "ruboty/ec2/actions/permit"
require "ruboty/ec2/actions/freeze"
require "ruboty/ec2/actions/thaw"
require "ruboty/ec2/actions/replicate"
require "ruboty/ec2/actions/repliarch"
require "ruboty/ec2/actions/privilege"
require "ruboty/ec2/actions/owner"

module Ruboty
  module Handlers
    class Ec2 < Base
      $stdout.sync = true

      # 自動起動／停止系
      on(/ec2 *autostart +(?<cmd>exec|list|add|del) *(?<ins_name>\S+)*\z/,
                                              name: 'autostart', description: 'manage auto-start instances')
      on(/ec2 *autostop +(?<cmd>exec|list|add|del) *(?<ins_name>\S+)*\z/,
                                              name: 'autostop',  description: 'manage auto-stop instances')

      # インスタンス操作系
      on(/ec2 *create +(?<ins_name>\S+) *(?<ami_id>\S+)*\z/,
                                              name: 'create',    description: 'create instance')
      on /ec2 *stop +(?<ins_name>\S+)\z/,     name: 'stop',      description: 'stop instance'
      on /ec2 *start +(?<ins_name>\S+)\z/,    name: 'start',     description: 'start instance'
      on /ec2 *destroy +(?<ins_name>\S+)\z/,  name: 'destroy',   description: 'destroy instance'
      on /ec2 *archive *(?<ins_name>\S+)*\z/, name: 'archive',   description: 'archive instance'
      on /ec2 *extract +(?<ins_name>\S+)\z/,  name: 'extract',   description: 'extract backed up instance'
      on /ec2 *rename +(?<old_ins_name>\S+) +(?<new_ins_name>\S+)\z/,
                                              name: 'rename',    description: 'rename instance name'
      on /ec2 *copy +(?<from_arc>\S+) +(?<to_ins>\S+)\z/,
                                              name: 'copy',      description: 'copy instance'
      on /ec2 *access +(?<cmd>give|revoke) +(?<ins_name>\S+) *(?<sg_name>\S+)*\z/,
                                              name: 'access',    description: 'manage access permit'
      on /ec2 *replicate +(?<from_multiins>\S+) +(?<to_multiins>\S+)\z/,
                                              name: 'replicate', description: 'create replica and set tag[ReplicaInfo]'
      on /ec2 *repliarch +(?<from_multiarc>\S+) +(?<to_multiins>\S+)\z/,
                                              name: 'repliarch', description: 'create replica from archive and set tag[ReplicaInfo]'

      # インスタンスメタ情報管理系
      on /ec2 *detail +(?<ins_name>\S+)\z/,   name: 'detail',    description: 'show instance/archive/AMI detail information'
      on(/ec2 *list *((?<resource>instance|archive|ami|summary)*|(?<resource>filter) +(?<word>\S+)+) *\z/,
                                              name: 'list',      description: 'show instance/archive/AMI list')
      on(/ec2 *usage *(?<yyyymm>last|20\d{4}+)*\z/,
                                              name: 'usage',     description: 'show instance usage of specified month')
      on(/ec2 *edit +(?<tag_name>spec|desc|param) +(?<ins_name>\S+) +(?<data>.+)\z/m,
                                              name: 'edit',      description: 'edit data of spec, desc and param')
      on(/ec2 *permit +(?<cmd>list|add|del) *(?<sg_name>\S+)* *(?<ip_csv>\S+)* *\z/,
                                              name: 'permit',    description: 'manage permitted source ip list')
      on /ec2 *freeze +(?<ins_name>\S+)\z/,   name: 'freeze',    description: 'freeze archive'
      on /ec2 *thaw +(?<ins_name>\S+)\z/,     name: 'thaw',      description: 'thaw frozen archive'
      on /ec2 +privilege +list\z/,            name: 'privilege', description: 'show privilege list'
      on(/ec2 +owner +(?<cmd>transfer|absence) *(?<ins_name>\S+)* *(?<to_user>\S+)* *\z/,
                                              name: 'owner',     description: 'manage ownership of instance')

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

      def rename(message)
        Ruboty::Ec2::Actions::Rename.new(message).call
      end

      def permit(message)
        Ruboty::Ec2::Actions::Permit.new(message).call
      end

      def freeze(message)
        Ruboty::Ec2::Actions::Freeze.new(message).call
      end

      def thaw(message)
        Ruboty::Ec2::Actions::Thaw.new(message).call
      end

      def replicate(message)
        Ruboty::Ec2::Actions::Replicate.new(message).call
      end

      def repliarch(message)
        Ruboty::Ec2::Actions::Repliarch.new(message).call
      end

      def privilege(message)
        Ruboty::Ec2::Actions::Privilege.new(message).call
      end

      def owner(message)
        Ruboty::Ec2::Actions::Owner.new(message).call
      end
    end
  end
end
