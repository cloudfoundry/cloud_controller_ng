require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RackAppBuilder do
    subject(:builder) { RackAppBuilder.new }

    describe '#build' do
      let(:request_metrics) { nil }

      it 'returns a Rack application' do
        expect(builder.build(TestConfig.config, request_metrics)).to be_a(Rack::Builder)
        expect(builder.build(TestConfig.config, request_metrics)).to respond_to(:call)
      end

      describe 'Rack::CommonLogger' do
        before do
          allow(Rack::CommonLogger).to receive(:new)
        end

        it 'uses Rack::CommonLogger when nginx is disabled' do
          builder.build(TestConfig.override(nginx: { use_nginx: false }), request_metrics).to_app

          expect(Rack::CommonLogger).to have_received(:new).with(anything, instance_of(File))
        end

        it 'does not use Rack::CommonLogger when nginx is enabled' do
          builder.build(TestConfig.override(nginx: { use_nginx: true }), request_metrics).to_app

          expect(Rack::CommonLogger).to_not have_received(:new)
        end
      end

      describe 'CEF logs' do
        before do
          allow(CloudFoundry::Middleware::CefLogs).to receive(:new)
        end

        it 'does not include Cef Middleware when security_event_logging is disabled' do
          builder.build(TestConfig.override(security_event_logging: { enabled: false }), request_metrics).to_app

          expect(CloudFoundry::Middleware::CefLogs).not_to have_received(:new)
        end

        it 'includes Cef Middleware when security_event_logging is enabled' do
          builder.build(TestConfig.override(security_event_logging: { enabled: true }), request_metrics).to_app

          expect(CloudFoundry::Middleware::CefLogs).to have_received(:new)
        end
      end
    end
  end
end
