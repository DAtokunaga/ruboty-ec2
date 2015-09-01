module Ruboty
  module Ec2
    module Actions
      class Extract < Ruboty::Actions::Base
        def call
          message.reply(extract)
        end

        private

        def extract
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
