module Ruboty
  module Ec2
    module Actions
      class Create < Ruboty::Actions::Base
        def call
          message.reply(create)
        end

        private

        def create
p message
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
