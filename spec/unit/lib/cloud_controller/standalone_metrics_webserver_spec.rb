require 'spec_helper'
require 'cloud_controller/standalone_metrics_webserver'
require 'cloud_controller/execution_context'

module VCAP::CloudController
  RSpec.describe StandaloneMetricsWebserver do
    let(:port) { 1899 }
    let(:server) { StandaloneMetricsWebserver.new(port) }
    let(:puma_server) { instance_double(Puma::Server, run: nil) }

    before do
      allow(server).to receive(:bosh_job_name).and_return('cloud_controller_ng')
      allow(Puma::Server).to receive(:new).and_return(puma_server)
      allow(Thread).to receive(:new).and_yield # otherwise the server runs in a separate thread and we can't test it
    end

    describe '#initialize' do
      it 'sets up the port' do
        expect(server.instance_variable_get(:@port)).to eq(port)
      end
    end

    describe '#start' do
      context 'when certificates are NOT configured' do
        before do
          allow(puma_server).to receive(:add_tcp_listener)
        end

        it 'configures and starts a Puma server' do
          server.start

          expect(puma_server).to have_received(:run)
          expect(Puma::Server).to have_received(:new).with(kind_of(Rack::Builder))
          expect(puma_server).to have_received(:add_tcp_listener).with('127.0.0.1', port)
        end
      end

      context 'when certificates are configured' do
        before do
          allow(server).to receive_messages(use_ssl?: true, cert_path: '/some/path/cert.pem', key_path: '/some/path/key.pem', ca_path: '/some/path/ca.pem')
          allow_any_instance_of(Puma::MiniSSL::Context).to receive(:check_file).and_return(true)
          allow(puma_server).to receive(:add_ssl_listener)
        end

        it 'configures and starts a Puma server with SSL' do
          server.start

          expect(puma_server).to have_received(:run)
          expect(Puma::Server).to have_received(:new).with(kind_of(Rack::Builder))
          expect(puma_server).to have_received(:add_ssl_listener).with('127.0.0.1', port, kind_of(Puma::MiniSSL::Context))
        end
      end
    end
  end
end
