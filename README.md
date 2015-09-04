# Ruboty::Ec2
ec2 controller for ruboty

## Usage

```ruby
# Gemfile
gem 'ruboty-ec2', '0.x.x', :git => 'git://github.com/miyaz/ruboty-ec2.git'
```

## ENV
```
RUBOTY_EC2_CHANNELS             - Multiple Channel Name for SakuttoKoutiku (comma separated variable)
RUBOTY_EC2_ACCESS_KEY_{CN}      - AWS Access Key for each Channel (CN = Channel Name)
RUBOTY_EC2_SECRET_KEY_{CN}      - AWS Secret Key for each Channel
RUBOTY_EC2_SUBNET_ID_{CN}       - VPC Subnet ID for each Channel
RUBOTY_EC2_RESTRICT_CMD_{CN}    - Restrict Command for each Channel (ex. cmd1:user1:user2,cmd2)
RUBOTY_EC2_DEFAULT_AMI_{CN}     - Default AMI ID for each Channel
RUBOTY_EC2_DOMAIN_{CN}          - Route53 Domain Name for each Channel
RUBOTY_EC2_REGION_{CN}          - AWS region for each Channel. (default: ap-northeast-1)
```

