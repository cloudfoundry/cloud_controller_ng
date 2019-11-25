require 'spec_helper'
require 'clients/kubernetes_kpack_client'

RSpec.describe Clients::KubernetesKpackClient do
  let(:kubernetes_creds) do
    {
      host_url: 'https://my.kubernetes.io',
      service_account: {
        name: 'username',
        token: 'token',
      },
      ca_crt: 'k8s_node_ca'
    }
  end

  it 'loads kubernetes creds from the config' do
    client = Clients::KubernetesKpackClient.new(kubernetes_creds).client
    expect(client.ssl_options).to eq({
      ca: 'k8s_node_ca'
    })

    expect(client.auth_options).to eq({
      bearer_token: 'token'
    })

    expect(client.api_endpoint.to_s).to eq 'https://my.kubernetes.io/apis/build.pivotal.io'
  end

  context 'when hostname is missing' do
    let(:kubernetes_creds) {
      {
        host_url: '',
        service_account: {
          name: 'username',
          token: 'token',
        },
        ca_crt: 'some-cert'
      }
    }

    it 'raises an error' do
      expect { Clients::KubernetesKpackClient.new(kubernetes_creds) }.to raise_error(Clients::KubernetesClient::InvalidURIError)
    end
  end
end
