module Ruboty
  module Ec2
    module Actions
      class Create < Ruboty::Actions::Base
        def call
          message.reply(create)
        end

        private

        def create
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
