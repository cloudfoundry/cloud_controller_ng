require 'kubeclient'

module Clients
  class KubernetesClient
    class MissingCredentialsError < StandardError; end

    attr_reader :client

    def initialize(host_url:, service_account:, ca_crt:)
      if [host_url, service_account, ca_crt].any?(&:blank?)
        raise MissingCredentialsError.new('Missing credentials for Kubernetes')
      end

      auth_options = {
        bearer_token: service_account[:token]
      }
      ssl_options = {
        ca: ca_crt
      }
      @client = Kubeclient::Client.new(
        host_url,
        'v1',
        auth_options: auth_options,
        ssl_options:  ssl_options
      )
    end
  end
end
