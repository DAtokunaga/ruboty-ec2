module Ruboty
  module Ec2
    module Actions
      class Copy < Ruboty::Actions::Base
        def call
          copy
        end

        private

        def copy
          # AWSアクセス、その他ユーティリティのインスタンス化
          util = Ruboty::Ec2::Helpers::Util.new(message)
          ec2  = Ruboty::Ec2::Helpers::Ec2.new(message)
          r53  = Ruboty::Ec2::Helpers::Route53.new(message)


          message.reply("TODO: write your logic.")
        rescue => e
          message.reply(e.message)
        end
      end
    end
  end
end
