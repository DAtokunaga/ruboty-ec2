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
      # price each instance type
      InsPrice   = {
        "t2.micro"  => 0.02,
        "t2.small"  => 0.04,
        "t2.medium" => 0.08,
        "m1.medium" => 0.122
      }
      # RHEL/CentOS price rate (t2.mediumの場合のRHEL/CentOSの料金倍率から算出)
      #   RHEL6(HVM)   t2.medium $0.14/hr
      #   CentOS6(HVM) t2.medium $0.08/hr
      #    => 0.14 / 0.08 = 1.75
      RhelCentPriceRate = 1.75

      # Period to archive(days)
      PeriodToArchive = 20
      # Period to archive notification(days)
      PeriodToArchiveNotice = 15
    end
  end
end
