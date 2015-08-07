module Ruboty
  module Ec2
    module Actions
      class Autostart < Ruboty::Actions::Base
        def call
          message.reply(autostart)
        end

        private

        def autostart
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
