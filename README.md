# Ruboty::Ec2
ec2 controller for ruboty

## Usage

```ruby
# Gemfile
gem 'ruboty-ec2', '0.x.x', :git => 'git://github.com/miyaz/ruboty-ec2.git'
```

## ENV
```
RUBOTY_EC2_CHANNELS        - Multiple Channel Name for SakuttoKoutiku (comma separated variable)
RUBOTY_EC2_ACCESS_KEY_{CN} - AWS Access Key for each CN (CN = Channel Name)
RUBOTY_EC2_SECRET_KEY_{CN} - AWS Secret Key for each CN
RUBOTY_EC2_SUBNET_ID_{CN}  - VPC Subnet ID for each CN
RUBOTY_EC2_DOMAIN_{CN}     - Route53 Domain Name for each CN
RUBOTY_EC2_REGION_{CN}     - AWS region for each CN. (default: ap-northeast-1)
```

