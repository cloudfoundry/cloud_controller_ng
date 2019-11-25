require 'clients/kubernetes_client'

module Clients
  class KubernetesKpackClient
    attr_reader :client

    def initialize(host_url:, service_account:, ca_crt:)
      raise KubernetesClient::InvalidURIError if host_url.empty?

      @client = KubernetesClient.new(
        api_group_url: "#{host_url}/apis/build.pivotal.io",
        version: 'v1alpha1',
        service_account: service_account,
        ca_crt: ca_crt,
      ).client
    end

    def create_image(*args)
      client.create_image(*args)
    end
  end
end
