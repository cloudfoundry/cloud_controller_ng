require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RackAppBuilder do
    subject(:builder) { RackAppBuilder.new }

    describe '#build' do
      let(:request_metrics) { double }
      let(:request_logs) { double }

      before do
        allow(CloudFoundry::Middleware::RequestMetrics).to receive(:new)
        allow(CloudFoundry::Middleware::RequestLogs).to receive(:new)
      end

      it 'returns a Rack application' do
        expect(builder.build(TestConfig.config_instance, request_metrics, request_logs)).to be_a(Rack::Builder)
        expect(builder.build(TestConfig.config_instance, request_metrics, request_logs)).to respond_to(:call)
      end

      it 'uses RequestMetrics and RequestLogs middleware' do
        builder.build(TestConfig.config_instance, request_metrics, request_logs).to_app

        expect(CloudFoundry::Middleware::RequestMetrics).to have_received(:new).with(anything, request_metrics)
        expect(CloudFoundry::Middleware::RequestLogs).to have_received(:new).with(anything, request_logs)
      end

      describe 'Rack::CommonLogger' do
        before do
          allow(Rack::CommonLogger).to receive(:new)
        end

        it 'uses Rack::CommonLogger when nginx is disabled' do
          builder.build(TestConfig.override(nginx: { use_nginx: false }), request_metrics, request_logs).to_app

          expect(Rack::CommonLogger).to have_received(:new).with(anything, instance_of(File))
        end

        it 'does not use Rack::CommonLogger when nginx is enabled' do
          builder.build(TestConfig.override(nginx: { use_nginx: true }), request_metrics, request_logs).to_app

          expect(Rack::CommonLogger).to_not have_received(:new)
        end
      end

      describe 'RateLimiter' do
        before do
          allow(CloudFoundry::Middleware::RateLimiter).to receive(:new)
        end

        context 'when configuring a limit' do
          before do
            builder.build(TestConfig.override(rate_limiter: {
              enabled: true,
              reset_interval_in_minutes: 60,
              general_limit: 123,
              total_general_limit: 1230,
              unauthenticated_limit: 1,
              total_unauthenticated_limit: 10
            }), request_metrics, request_logs).to_app
          end

          it 'enables the RateLimiter middleware' do
            expect(CloudFoundry::Middleware::RateLimiter).to have_received(:new).with(
              anything,
              logger: instance_of(Steno::Logger),
              general_limit: 123,
              total_general_limit: 1230,
              unauthenticated_limit: 1,
              total_unauthenticated_limit: 10,
              interval: 60
            )
          end
        end

        context 'when not configuring a limit' do
          before do
            builder.build(TestConfig.override(rate_limiter: {
              enabled: false,
              reset_interval_in_minutes: 60,
              general_limit: 123,
              total_general_limit: 1230,
              unauthenticated_limit: 1,
              total_unauthenticated_limit: 10
            }), request_metrics, request_logs).to_app
          end

          it 'does not enable the RateLimiter middleware' do
            expect(CloudFoundry::Middleware::RateLimiter).not_to have_received(:new)
          end
        end
      end

      describe 'New Relic custom attributes' do
        before do
          allow(CloudFoundry::Middleware::NewRelicCustomAttributes).to receive(:new)
        end

        context 'when new relic is enabled' do
          before do
            builder.build(TestConfig.override(newrelic_enabled: true), request_metrics, request_logs).to_app
          end

          it 'enables the New Relic custom attribute middleware' do
            expect(CloudFoundry::Middleware::NewRelicCustomAttributes).to have_received(:new)
          end
        end

        context 'when new relic is NOT enabled' do
          before do
            builder.build(TestConfig.override(newrelic_enabled: false), request_metrics, request_logs).to_app
          end

          it 'does NOT enable the New Relic custom attribute middleware' do
            expect(CloudFoundry::Middleware::NewRelicCustomAttributes).not_to have_received(:new)
          end
        end
      end

      describe 'CEF logs' do
        before do
          allow(CloudFoundry::Middleware::CefLogs).to receive(:new)
        end

        it 'does not include Cef Middleware when security_event_logging is disabled' do
          builder.build(TestConfig.override(security_event_logging: { enabled: false }), request_metrics, request_logs).to_app

          expect(CloudFoundry::Middleware::CefLogs).not_to have_received(:new)
        end

        it 'includes Cef Middleware when security_event_logging is enabled' do
          fake_logger = instance_double(Logger)
          allow(Logger).to receive(:new).with(TestConfig.config_instance.get(:security_event_logging, :file)).and_return(fake_logger)
          enabled_config = TestConfig.config_instance.get(:security_event_logging).merge(enabled: true)
          builder.build(TestConfig.override(security_event_logging: enabled_config), request_metrics, request_logs).to_app

          expect(CloudFoundry::Middleware::CefLogs).to have_received(:new).with(anything, fake_logger, TestConfig.config_instance.get(:local_route))
        end
      end
    end
  end
end
