require "ruboty/ec2/actions/create"
require "ruboty/ec2/actions/destroy"
require "ruboty/ec2/actions/start"
require "ruboty/ec2/actions/list"
require "ruboty/ec2/actions/stop"
require "ruboty/ec2/actions/desc"
require "ruboty/ec2/actions/spec"

module Ruboty
  module Handlers
    class Ec2 < Base
      on /ec2 create/, name: 'create', description: 'TODO: write your description'
      on /ec2 destroy/, name: 'destroy', description: 'TODO: write your description'
      on /ec2 start/, name: 'start', description: 'TODO: write your description'
      on /ec2 list/, name: 'list', description: 'TODO: write your description'
      on /ec2 stop/, name: 'stop', description: 'TODO: write your description'
      on /ec2 desc/, name: 'desc', description: 'TODO: write your description'
      on /ec2 spec/, name: 'spec', description: 'TODO: write your description'

      def create(message)
        Ruboty::Ec2::Actions::Create.new(message).call
      end

      def destroy(message)
        Ruboty::Ec2::Actions::Destroy.new(message).call
      end

      def start(message)
        Ruboty::Ec2::Actions::Start.new(message).call
      end

      def list(message)
        Ruboty::Ec2::Actions::List.new(message).call
      end

      def stop(message)
        Ruboty::Ec2::Actions::Stop.new(message).call
      end

      def desc(message)
        Ruboty::Ec2::Actions::Desc.new(message).call
      end

      def spec(message)
        Ruboty::Ec2::Actions::Spec.new(message).call
      end
    end
  end
end
