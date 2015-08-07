module Ruboty
  module Ec2
    module Actions
      class Dontstop < Ruboty::Actions::Base
        def call
          message.reply(dontstop)
        end

        private

        def dontstop
          "TODO: write your logic."
        rescue => e
          e.message
        end
      end
    end
  end
end
