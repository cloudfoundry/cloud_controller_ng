require 'kubeclient'
require 'uri'

module Kubernetes
  # KubeClientBuilder is a factory that takes in Kubernetes connection config and
  # returns an instance of a KubeClient.
  class KubeClientBuilder
    class Error < StandardError; end
    class MissingCredentialsError < Error; end

    class << self
      def build(api_group_url:, version:, service_account_token:, ca_crt:)
        if [api_group_url, service_account_token, ca_crt].any?(&:blank?)
          raise MissingCredentialsError.new('Missing credentials for Kubernetes')
        end

        auth_options = {
          bearer_token: service_account_token
        }
        ssl_options = {
          ca: ca_crt
        }

        Kubeclient::Client.new(
          api_group_url.to_s,
          version,
          auth_options: auth_options,
          ssl_options:  ssl_options
        )
      end
    end
  end
end
