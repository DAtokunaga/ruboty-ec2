module Ruboty
  module Ec2
    module Actions
      class Backup < Ruboty::Actions::Base
        def call
          message.reply(backup)
        end

        private

        def backup
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
