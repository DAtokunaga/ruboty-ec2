module Ruboty
  module Ec2
    module Actions
      class Start < Ruboty::Actions::Base
        def call
          message.reply(start)
        end

        private

        def start
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
