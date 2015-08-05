module Ruboty
  module Ec2
    module Actions
      class Restore < Ruboty::Actions::Base
        def call
          message.reply(restore)
        end

        private

        def restore
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
