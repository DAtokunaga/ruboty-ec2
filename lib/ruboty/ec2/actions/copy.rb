module Ruboty
  module Ec2
    module Actions
      class Copy < Ruboty::Actions::Base
        def call
          message.reply(copy)
        end

        private

        def copy
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
