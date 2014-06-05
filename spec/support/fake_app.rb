require "support/fake_nginx_reverse_proxy"

class FakeApp < VCAP::CloudController::FrontController
  def initialize(config)
    token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
    super(config, token_decoder)
  end
end
FakeApp.use(FakeNginxReverseProxy)