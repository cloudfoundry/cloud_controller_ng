require 'spec_helper'
require 'kubernetes/kube_client_builder'

RSpec.describe Kubernetes::KubeClientBuilder do
  let(:kubernetes_creds) do
    {
      api_group_url: 'https://my.kubernetes.io/apis/whatever',
      version: 'v1',
      service_account_token: 'token',
      ca_crt: 'k8s_node_ca'
    }
  end

  it 'loads kubernetes creds from the config' do
    client = Kubernetes::KubeClientBuilder.build(kubernetes_creds)

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
        service_account_token: 'token',
        ca_crt: nil
      }
    }

    it 'raises an error' do
      expect { Kubernetes::KubeClientBuilder.build(kubernetes_creds) }.to raise_error(Kubernetes::KubeClientBuilder::MissingCredentialsError)
    end
  end
end
