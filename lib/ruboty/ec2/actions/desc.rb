module Ruboty
  module Ec2
    module Actions
      class Desc < Ruboty::Actions::Base
        def call
          message.reply(desc)
        end

        private

        def desc
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
