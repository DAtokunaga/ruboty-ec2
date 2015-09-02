module Ruboty
  module Ec2
    module Actions
      class Extract < Ruboty::Actions::Base
        def call
          extract
        end

        private

        def extract
          message.reply("TODO: write your logic.")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
