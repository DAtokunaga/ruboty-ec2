# -*- coding: utf-8 -*-
## Ruboty::Ec2::Helpers::Slack

require 'addressable/uri'

module Ruboty
  module Ec2
    module Helpers
      class Slack
        # set const var
        SLACK_USERS_API = "https://slack.com/api/users.list"
        SLACK_API_TOKEN = ENV['SLACK_API_TOKEN']

        def initialize(message)
          @message = message
        end

        # Slack APIを使用してUserList取得
        def get_slack_user_list
          uri   = Addressable::URI.parse(SLACK_USERS_API)
          query = {token: SLACK_API_TOKEN, presence: 0}
    
          uri.query_values ||= {}
          uri.query_values   = uri.query_values.merge(query)
 
          res_json = Net::HTTP.get(URI.parse(uri))
          res_hash = JSON.parse(res_json, {:symbolize_names => true})
          users_hash = {}
          res_hash[:members].each do |mem_hash|
            next if mem_hash[:profile][:email].nil? or mem_hash[:profile][:email].empty?
            next if mem_hash[:name].nil? or mem_hash[:name].empty?
            email = mem_hash[:profile][:email]
            name  = mem_hash[:name]
            flag  = mem_hash[:deleted]
            users_hash[email] = {:email => email, :name => name, :disabled => flag}
          end
          raise "api response : #{res_hash}" if res_hash.nil? or !res_hash[:ok]
          users_hash
        end
      end
    end
  end
end
