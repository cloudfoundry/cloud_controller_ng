module RequestSpecHelper
  ENV['RACK_ENV'] = 'test'

  def app
    test_config     = TestConfig.config_instance
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end
end
