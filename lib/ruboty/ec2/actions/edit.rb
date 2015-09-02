module Ruboty
  module Ec2
    module Actions
      class Edit < Ruboty::Actions::Base
        def call
          edit
        end

        private

        def edit
          message.reply("TODO: write your logic.")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
