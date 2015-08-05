module Ruboty
  module Ec2
    module Actions
      class Stop < Ruboty::Actions::Base
        def call
          message.reply(stop)
        end

        private

        def stop
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
