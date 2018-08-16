require 'spec_helper'
require 'logcache/client'
require 'openssl'

module Logcache
  RSpec.describe Client do
    let(:logcache_envelopes) { [42, :woof] }
    let(:logcache_service) { instance_double(Logcache::V1::Egress::Stub, read: logcache_envelopes) }
    let(:logcache_request) { instance_double(Logcache::V1::ReadRequest) }

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
    let(:client_ca) { File.open(client_ca_path).read }
    let(:client_key) { File.open(client_key_path).read }
    let(:client_cert) { File.open(client_cert_path).read }

    describe '#container_metrics' do
      let(:instance_count) { 2 }
      let!(:process) { VCAP::CloudController::ProcessModel.make(instances: instance_count) }

      before do
        expect(GRPC::Core::ChannelCredentials).to receive(:new).
          with(client_ca, client_key, client_cert).
          and_return(credentials)
        expect(Logcache::V1::Egress::Stub).to receive(:new).
          with("#{host}:#{port}", credentials, channel_arg_hash).
          and_return(logcache_service)
        allow(Logcache::V1::ReadRequest).to receive(:new).and_return(logcache_request)
      end

      it 'calls Logcache with the correct parameters and returns envelopes' do
        expect(
          client.container_metrics(source_guid: process.guid, envelope_limit: 1000)
        ).to eq([42, :woof])

        expect(Logcache::V1::ReadRequest).to have_received(:new).with(
          source_id: process.guid,
          limit: 1000,
          descending: true,
          envelope_types: [:GAUGE]
        )
        expect(logcache_service).to have_received(:read).with(logcache_request)
      end
    end
  end
end
