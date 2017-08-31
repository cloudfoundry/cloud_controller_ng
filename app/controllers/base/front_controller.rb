require 'cloud_controller/security/security_context_configurer'

module VCAP::CloudController
  include VCAP::RestAPI

  class FrontController < Sinatra::Base
    register Sinatra::VCAP

    attr_reader :config

    vcap_configure(logger_name: 'cc.api', reload_path: File.dirname(__FILE__))

    def initialize(config)
      @config = config
      super()
    end

    before do
      I18n.locale = env['HTTP_ACCEPT_LANGUAGE']
    end
  end
end
