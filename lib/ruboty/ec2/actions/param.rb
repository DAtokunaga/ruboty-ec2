module Ruboty
  module Ec2
    module Actions
      class Param < Ruboty::Actions::Base
        def call
          message.reply(param)
        end

        private

        def param
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
