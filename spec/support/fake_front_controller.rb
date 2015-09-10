require 'support/fake_nginx_reverse_proxy'

class FakeFrontController < VCAP::CloudController::FrontController
  use(FakeNginxReverseProxy)

  def initialize(config)
    token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    super(config, token_decoder, request_metrics)
  end
end
