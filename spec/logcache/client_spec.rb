require 'spec_helper'
require 'logcache/client'
require 'openssl'

module Logcache
  RSpec.describe Client do
    let(:logcache_envelopes) { [:fake_envelope_1, :fake_envelope_2] }
    let(:logcache_service) { instance_double(Logcache::V1::Egress::Stub, read: logcache_envelopes) }
    let(:logcache_request) { instance_double(Logcache::V1::ReadRequest) }

    let(:host) { 'doppler.service.cf.internal' }
    let(:port) { '8080' }
    let(:tls_subject_name) { 'my-logcache' }
    let(:client_ca_path) { File.join(Paths::FIXTURES, 'certs/log_cache_ca.crt') }
    let(:client_cert_path) { File.join(Paths::FIXTURES, 'certs/log_cache.crt') }
    let(:client_key_path) { File.join(Paths::FIXTURES, 'certs/log_cache.key') }
    let(:credentials) { instance_double(GRPC::Core::ChannelCredentials) }
    let(:channel_arg_hash) do
      {
          channel_args: { GRPC::Core::Channel::SSL_TARGET => tls_subject_name }
      }
    end
    let(:client) do
      Logcache::Client.new(host: host, port: port, client_ca_path: client_ca_path,
                           client_cert_path: client_cert_path, client_key_path: client_key_path, tls_subject_name: tls_subject_name)
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
          client.container_metrics(source_guid: process.guid, envelope_limit: 1000, start_time: 100, end_time: 101)
        ).to eq([:fake_envelope_1, :fake_envelope_2])

        expect(Logcache::V1::ReadRequest).to have_received(:new).with(
          source_id: process.guid,
          limit: 1000,
          descending: true,
          start_time: 100,
          end_time: 101,
          envelope_types: [:GAUGE]
        )
        expect(logcache_service).to have_received(:read).with(logcache_request)
      end
    end

    describe 'when logcache is unavailable' do
      let(:instance_count) { 0 }
      let(:bad_status) { GRPC::BadStatus.new(14) }
      let!(:process) { VCAP::CloudController::ProcessModel.make(instances: instance_count) }

      before do
        expect(GRPC::Core::ChannelCredentials).to receive(:new).
          with(client_ca, client_key, client_cert).
          and_return(credentials)
        expect(Logcache::V1::Egress::Stub).to receive(:new).
          with("#{host}:#{port}", credentials, channel_arg_hash).
          and_return(logcache_service)
        allow(client).to receive(:sleep)
        allow(Logcache::V1::ReadRequest).to receive(:new).and_return(logcache_request)
        allow(logcache_service).to receive(:read).and_raise(bad_status)
      end

      it 'returns an empty envelope' do
        expect(
          client.container_metrics(source_guid: process.guid, envelope_limit: 1000, start_time: 100, end_time: 101)
        ).to be_a(Logcache::EmptyEnvelope)
      end

      it 'retries the request three times' do
        client.container_metrics(source_guid: process.guid, envelope_limit: 1000, start_time: 100, end_time: 101)

        expect(logcache_service).to have_received(:read).with(logcache_request).exactly(3).times
      end
    end

    describe 'when the logcache service has any other error' do
      let(:bad_status) { GRPC::BadStatus.new(13) }
      let!(:process) { VCAP::CloudController::ProcessModel.make(instances: instance_count) }
      let(:instance_count) { 2 }

      before do
        expect(GRPC::Core::ChannelCredentials).to receive(:new).
          with(client_ca, client_key, client_cert).
          and_return(credentials)
        expect(Logcache::V1::Egress::Stub).to receive(:new).
          with("#{host}:#{port}", credentials, channel_arg_hash).
          and_return(logcache_service)
        allow(client).to receive(:sleep)
        allow(Logcache::V1::ReadRequest).to receive(:new).and_return(logcache_request)
        allow(logcache_service).to receive(:read).and_raise(bad_status)
      end

      it 'raises the exception' do
        expect {
          client.container_metrics(source_guid: process.guid, envelope_limit: 1000, start_time: 100, end_time: 101)
        }.to raise_error(bad_status)
      end
    end
  end
end
