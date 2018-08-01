require 'cloud_controller/security/security_context_configurer'
require 'cloud_controller/request_scheme_validator'

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
      validate_scheme!
    end

    private

    def validate_scheme!
      validator = CloudController::RequestSchemeValidator.new
      current_user = VCAP::CloudController::SecurityContext.current_user
      roles = VCAP::CloudController::SecurityContext.roles

      validator.validate!(current_user, roles, @config, request)
    end
  end
end
