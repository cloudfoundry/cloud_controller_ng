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

          expect(Rack::CommonLogger).not_to have_received(:new)
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
                                                per_process_general_limit: 123,
                                                global_general_limit: 1230,
                                                per_process_unauthenticated_limit: 1,
                                                global_unauthenticated_limit: 10
                                              }), request_metrics, request_logs).to_app
          end

          it 'enables the RateLimiter middleware' do
            expect(CloudFoundry::Middleware::RateLimiter).to have_received(:new).with(
              anything,
              logger: instance_of(Steno::Logger),
              per_process_general_limit: 123,
              global_general_limit: 1230,
              per_process_unauthenticated_limit: 1,
              global_unauthenticated_limit: 10,
              interval: 60
            )
          end
        end

        context 'when not configuring a limit' do
          before do
            builder.build(TestConfig.override(rate_limiter: {
                                                enabled: false,
                                                reset_interval_in_minutes: 60,
                                                per_process_general_limit: 123,
                                                global_general_limit: 1230,
                                                per_process_unauthenticated_limit: 1,
                                                global_unauthenticated_limit: 10
                                              }), request_metrics, request_logs).to_app
          end

          it 'does not enable the RateLimiter middleware' do
            expect(CloudFoundry::Middleware::RateLimiter).not_to have_received(:new)
          end
        end
      end

      describe 'ServiceBrokerRateLimiter' do
        before do
          allow(CloudFoundry::Middleware::ServiceBrokerRateLimiter).to receive(:new)
        end

        context 'when configuring a limit' do
          before do
            builder.build(TestConfig.override(max_concurrent_service_broker_requests: 5), request_metrics, request_logs).to_app
          end

          it 'enables the ServiceBrokerRateLimiter middleware' do
            expect(CloudFoundry::Middleware::ServiceBrokerRateLimiter).to have_received(:new).with(
              anything,
              logger: instance_of(Steno::Logger),
              max_concurrent_requests: TestConfig.config_instance.get(:max_concurrent_service_broker_requests),
              broker_timeout_seconds: TestConfig.config_instance.get(:broker_client_timeout_seconds)
            )
          end
        end

        context 'when not configuring a limit' do
          before do
            builder.build(TestConfig.override(max_concurrent_service_broker_requests: 0), request_metrics, request_logs).to_app
          end

          it 'does not enable the ServiceBrokerRateLimiter middleware' do
            expect(CloudFoundry::Middleware::ServiceBrokerRateLimiter).not_to have_received(:new)
          end
        end
      end

      describe 'RateLimiterV2API' do
        before do
          allow(CloudFoundry::Middleware::RateLimiterV2API).to receive(:new)
        end

        context 'when configuring a limit' do
          before do
            builder.build(TestConfig.override(rate_limiter_v2_api: {
                                                enabled: true,
                                                reset_interval_in_minutes: 5,
                                                per_process_general_limit: 10,
                                                global_general_limit: 100,
                                                per_process_admin_limit: 20,
                                                global_admin_limit: 200
                                              }), request_metrics, request_logs).to_app
          end

          it 'enables the RateLimiterV2API middleware' do
            expect(CloudFoundry::Middleware::RateLimiterV2API).to have_received(:new).with(
              anything,
              logger: instance_of(Steno::Logger),
              per_process_general_limit: 10,
              global_general_limit: 100,
              per_process_admin_limit: 20,
              global_admin_limit: 200,
              interval: 5
            )
          end
        end

        context 'when not configuring a limit' do
          before do
            builder.build(TestConfig.override(rate_limiter_v2_api: {
                                                enabled: false,
                                                per_process_general_limit: 10,
                                                global_general_limit: 100,
                                                per_process_admin_limit: 20,
                                                global_admin_limit: 200,
                                                reset_interval_in_minutes: 5
                                              }), request_metrics, request_logs).to_app
          end

          it 'does not enable the ServiceBrokerRateLimiter middleware' do
            expect(CloudFoundry::Middleware::RateLimiterV2API).not_to have_received(:new)
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

      describe 'Below Min Cli Warning' do
        before do
          allow(CloudFoundry::Middleware::BelowMinCliWarning).to receive(:new)
        end

        context 'with min_cf_cli_version and warn flag provided' do
          before do
            builder.build(TestConfig.override(info: { min_cli_version: '7.0.0' }, warn_if_below_min_cli_version: true), request_metrics, request_logs).to_app
          end

          it 'enables the BelowMinCliWarning middleware' do
            expect(CloudFoundry::Middleware::BelowMinCliWarning).to have_received(:new)
          end
        end

        context 'without min_cf_cli_version provided and warn flag' do
          it 'does not enable the BelowMinCliWarning middleware' do
            expect(CloudFoundry::Middleware::BelowMinCliWarning).not_to have_received(:new)
          end
        end
      end
    end
  end
end
