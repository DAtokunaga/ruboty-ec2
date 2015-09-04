require "ruboty/ec2/version"
require "ruboty/handlers/ec2"

module Ruboty
  module Ec2
    class Const
      # keypair name
      KeyName = "sakutto-key"
      # volume type
      VolType = "gp2"
      # iam instance profile name
      IamRole = "sakutto-ec2"
      # instance type (for paravirtual in use RHEL/CentOS 5)
      InsTypePV  = "m1.medium"
      # instance type (for hvm in use RHEL/CentOS 6 later)
      InsTypeHVM = "t2.medium"

      # Period to archive(days)
      PeriodToArchive = 20
      # Period to archive notification(days)
      PeriodToArchiveNotice = 15
    end
  end
end
