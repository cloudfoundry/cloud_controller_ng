module RequestSpecHelper
  ENV['RACK_ENV'] = 'test'

  def app
    test_config     = TestConfig.config_instance
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    request_logs    = VCAP::CloudController::Logs::RequestLogs.new(Steno.logger('request.logs'))
    VCAP::CloudController::RackAppBuilder.new.build(test_config, request_metrics, request_logs)
  end
end
