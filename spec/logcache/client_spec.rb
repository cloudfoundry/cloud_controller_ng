require 'spec_helper'
require 'logcache/client'
require 'openssl'

module Logcache
  RSpec.describe Client do
    let(:logcache_envelopes) { [42, :woof] }
    let(:logcache_service) { instance_double(Logcache::V1::Egress::Stub, read: logcache_envelopes) }

    let(:host) { 'doppler.service.cf.internal' }
    let(:port) { '8080' }
    let(:client_ca_path) { File.join(Paths::FIXTURES, 'certs/log_cache_ca.crt') }
    let(:client_cert_path) { File.join(Paths::FIXTURES, 'certs/log_cache.crt') }
    let(:client_key_path) { File.join(Paths::FIXTURES, 'certs/log_cache.key') }
    let(:credentials) { instance_double(GRPC::Core::ChannelCredentials) }
    let(:channel_arg_hash) do
      {
        channel_args: { GRPC::Core::Channel::SSL_TARGET => 'log_cache' }
      }
    end
    let(:client) do
      Logcache::Client.new(host: host, port: port, client_ca_path: client_ca_path,
                           client_cert_path: client_cert_path, client_key_path: client_key_path)
    end
    let(:expected_request_options) { { 'headers' => { 'Authorization' => 'bearer oauth-token' } } }

    before do
      client_ca = File.open(client_ca_path).read
      client_key = File.open(client_key_path).read
      client_cert = File.open(client_cert_path).read

      allow(GRPC::Core::ChannelCredentials).to receive(:new).
        with(client_ca, client_key, client_cert).
        and_return(credentials)
      allow(Logcache::V1::Egress::Stub).to receive(:new).
        with("#{host}:#{port}", credentials, channel_arg_hash).
        and_return(logcache_service)
      allow_any_instance_of(Logcache::Client).to receive(:build_read_request)
    end

    it 'can get some envelopes' do
      expect(client.container_metrics(app_guid: 'my-app-guid')).to eq([42, :woof])
    end
  end
end
