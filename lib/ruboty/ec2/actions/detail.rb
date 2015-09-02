module Ruboty
  module Ec2
    module Actions
      class Detail < Ruboty::Actions::Base
        def call
          detail
        end

        private

        def detail
          message.reply("TODO: write your logic.")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
