require "ruboty/ec2/version"
require "ruboty/handlers/ec2"

module Ruboty
  module Ec2
    class Const
      # keypair name
      KeyName = "sakutto-key"
      # instance type
      InsType = "t2.micro"
      # volume type
      VolType = "gp2"
      # iam instance profile name
      IamRole = "sakutto-ec2"
    end
  end
end
