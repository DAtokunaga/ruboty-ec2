module Ruboty
  module Ec2
    module Actions
      class Destroy < Ruboty::Actions::Base
        def call
          message.reply(destroy)
        end

        private

        def destroy
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
