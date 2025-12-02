# -*- encoding: utf-8 -*-

module Aliyun
  module STS

    # STS服务的客户端，用于向STS申请临时token。
    # @example 创建Client
    #   client = Client.new(
    #     :access_key_id => 'access_key_id',
    #     :access_key_secret => 'access_key_secret')
    #   token = client.assume_role('role:arn', 'app')
    #
    #   policy = Policy.new
    #   policy.allow(['oss:Get*'], ['acs:oss:*:*:my-bucket/*'])
    #   token = client.assume_role('role:arn', 'app', policy, 60)
    #   puts token.to_s
    class Client

      def initialize(opts)
        @config = Config.new(opts)
        @protocol = Protocol.new(@config)
      end

      # Assume a role
      # @param role [String] the role arn
      # @param session [String] the session name
      # @param policy [STS::Policy] the policy
      # @param duration [Integer] the duration seconds for the
      #  requested token
      # @return [STS::Token] the sts token
      def assume_role(role, session, policy = nil, duration = 3600)
        @protocol.assume_role(role, session, policy, duration)
      end

    end # Client

  end # STS
end # Aliyun
