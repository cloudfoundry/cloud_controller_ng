require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ApiMetricsWebserver do
    let(:metrics_webserver) { described_class.new }
    let(:puma_server_double) { instance_double(Puma::Server, add_tcp_listener: nil, add_unix_listener: nil, run: nil) }
    let(:config) { double('config', get: nil) }

    before do
      allow(Puma::Server).to receive(:new).and_return(puma_server_double)
    end

    describe '#start' do
      it 'configures and starts a Puma server' do
        expect(puma_server_double).to receive(:run)

        metrics_webserver.start(config)

        expect(Puma::Server).to have_received(:new).with(an_instance_of(Rack::Builder))
      end

      context 'when no socket is specified' do
        before do
          allow(config).to receive(:get).with(:nginx, :metrics_socket).and_return(nil)
        end

        it 'uses a TCP listener' do
          expect(puma_server_double).to receive(:add_tcp_listener).with('127.0.0.1', 9395)

          metrics_webserver.start(config)
        end
      end

      context 'when a socket is specified' do
        before do
          allow(config).to receive(:get).with(:nginx, :metrics_socket).and_return('/tmp/metrics.sock')
        end

        it 'uses a Unix socket listener' do
          expect(puma_server_double).to receive(:add_unix_listener).with('/tmp/metrics.sock')

          metrics_webserver.start(config)
        end
      end
    end
  end
end
