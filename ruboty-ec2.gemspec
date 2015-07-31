# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ruboty/ec2/version'

Gem::Specification.new do |spec|
  spec.name          = "ruboty-ec2"
  spec.version       = Ruboty::Ec2::VERSION
  spec.authors       = ["miyaz"]
  spec.email         = ["shi_miyazato_r@dreamarts.co.jp"]
  spec.summary       = %q{Sakutto Kouchiku EC2 Control}
  spec.description   = %q{Sakutto Kouchiku EC2 Control}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "ruboty"
  spec.add_runtime_dependency "aws-sdk", "~> 2.0.0"
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
