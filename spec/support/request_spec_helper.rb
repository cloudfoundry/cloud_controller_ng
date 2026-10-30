module RequestSpecHelper
  ENV['RACK_ENV'] = 'test'

  def app
    test_config     = TestConfig.config_instance
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    request_logs    = VCAP::CloudController::Logs::RequestLogs.new(Steno.logger('request.logs'))
    rack_app        = VCAP::CloudController::RackAppBuilder.new.build(test_config, request_metrics, request_logs)

    # A no-op unless OPENAPI_CONFORMANCE is set. See openapi_conformance.rb.
    OpenapiConformance.wrap(rack_app)
  end
end
