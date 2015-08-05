module Ruboty
  module Ec2
    module Actions
      class Edit < Ruboty::Actions::Base
        def call
          message.reply(edit)
        end

        private

        def edit
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
