module Ruboty
  module Ec2
    module Actions
      class Autostop < Ruboty::Actions::Base
        def call
          autostop
        end

        private

        def autostop
          message.reply("TODO: write your logic.")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
