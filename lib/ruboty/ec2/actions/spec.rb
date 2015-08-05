module Ruboty
  module Ec2
    module Actions
      class Spec < Ruboty::Actions::Base
        def call
          message.reply(spec)
        end

        private

        def spec
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
