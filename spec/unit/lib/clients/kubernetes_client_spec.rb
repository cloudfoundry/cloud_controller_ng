require 'spec_helper'
require 'clients/kubernetes_client'

RSpec.describe Clients::KubernetesClient do
  let(:kubernetes_creds) do
    {
      api_group_url: 'https://my.kubernetes.io/apis/whatever',
      version: 'v1',
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

    expect(client.api_endpoint.to_s).to eq 'https://my.kubernetes.io/apis/whatever'
  end

  context 'when credentials are missing' do
    let(:kubernetes_creds) {
      {
        api_group_url: 'https://my.kubernetes.io/api',
        version: 'v1',
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
