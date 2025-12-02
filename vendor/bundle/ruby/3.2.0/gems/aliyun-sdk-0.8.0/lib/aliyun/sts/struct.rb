# -*- encoding: utf-8 -*-

require 'json'
require 'cgi'

module Aliyun
  module STS

    # STS Policy. Referer to
    # https://help.aliyun.com/document_detail/ram/ram-user-guide/policy_reference/struct_def.html for details.
    class Policy < Common::Struct::Base
      VERSION = '1'

      attrs :rules

      # Add an 'Allow' rule
      # @param actions [Array<String>] actions of the rule. e.g.:
      #  oss:GetObject, oss:Get*, oss:*
      # @param resources [Array<String>] resources of the rule. e.g.:
      #  acs:oss:*:*:my-bucket, acs:oss:*:*:my-bucket/*, acs:oss:*:*:*
      def allow(actions, resources)
        add_rule(true, actions, resources)
      end

      # Add an 'Deny' rule
      # @param actions [Array<String>] actions of the rule. e.g.:
      #  oss:GetObject, oss:Get*, oss:*
      # @param resources [Array<String>] resources of the rule. e.g.:
      #  acs:oss:*:*:my-bucket, acs:oss:*:*:my-bucket/*, acs:oss:*:*:*
      def deny(actions, resources)
        add_rule(false, actions, resources)
      end

      # Serialize to rule to string
      def serialize
        {'Version' => VERSION, 'Statement' => @rules}.to_json
      end

      private
      def add_rule(allow, actions, resources)
        @rules ||= []
        @rules << {
          'Effect' => allow ? 'Allow' : 'Deny',
          'Action' => actions,
          'Resource' => resources
        }
      end
    end

    # STS token. User may use the credentials included to access
    # Alicloud resources(OSS, OTS, etc).
    # Attributes:
    # * access_key_id [String] the AccessKeyId
    # * access_key_secret [String] the AccessKeySecret
    # * security_token [String] the SecurityToken
    # * expiration [Time] the time when the token will be expired
    # * session_name [String] the session name for this token
    class Token < Common::Struct::Base
      attrs :access_key_id, :access_key_secret,
            :security_token, :expiration, :session_name
    end

  end # STS
end # Aliyun
