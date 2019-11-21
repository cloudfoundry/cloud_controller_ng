require 'spec_helper'
require 'clients/kubernetes_client'

RSpec.describe Clients::KubernetesClient do
  let(:kubernetes_creds) do
    {
      host_url: 'my_kubernetes.io/api',
      service_account: {
        name: 'username',
        token: 'token',
      },
      ca_crt: 'k8s_node_ca'
    }
  end

  it 'loads kubernetes creds from the config' do
    client = Clients::KubernetesClient.new(kubernetes_creds).client

    expect(client.ssl_options).to eq({
      ca: 'k8s_node_ca'
    })

    expect(client.auth_options).to eq({
      bearer_token: 'token'
    })

    expect(client.api_endpoint.to_s).to eq 'my_kubernetes.io/api'
  end

  context 'when credentials are missing' do
    let(:kubernetes_creds) {
      {
        host_url: 'my_kubernetes.io/api',
        service_account: {
          name: 'username',
          token: 'token',
        },
        ca_crt: nil
      }
    }

    it 'raises an error' do
      expect { Clients::KubernetesClient.new(kubernetes_creds) }.to raise_error(Clients::KubernetesClient::MissingCredentialsError)
    end
  end
end
