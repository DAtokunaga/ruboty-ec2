module Ruboty
  module Ec2
    module Actions
      class Archive < Ruboty::Actions::Base
        def call
          message.reply(archive)
        end

        private

        def archive
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
