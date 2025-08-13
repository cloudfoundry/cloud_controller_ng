require 'spec_helper'

module VCAP::CloudController
  RSpec.describe MetricsWebserver do
    let(:metrics_webserver) { described_class.new }
    let(:config) { double('config', get: nil) }

    describe '#start' do
      it 'configures and starts a Puma server' do
        allow(Puma::Server).to receive(:new).and_call_original
      end

      context 'when no socket is specified' do
        before do
          allow(config).to receive(:get).with(:nginx, :metrics_socket).and_return(nil)
        end

        it 'uses a TCP listener' do
          expect_any_instance_of(Puma::Server).to receive(:add_tcp_listener).with('127.0.0.1', 9395)
          expect_any_instance_of(Puma::Server).to receive(:run)

          metrics_webserver.start(config)
        end
      end

      context 'when a socket is specified' do
        before do
          allow(config).to receive(:get).with(:nginx, :metrics_socket).and_return('/tmp/metrics.sock')
        end

        it 'uses a Unix socket listener' do
          expect_any_instance_of(Puma::Server).to receive(:add_unix_listener).with('/tmp/metrics.sock')
          expect_any_instance_of(Puma::Server).to receive(:run)

          metrics_webserver.start(config)
        end
      end
    end
  end
end
