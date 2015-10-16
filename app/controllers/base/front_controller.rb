require 'cloud_controller/security/security_context_configurer'
require 'cloud_controller/request_scheme_validator'

module VCAP::CloudController
  include VCAP::RestAPI

  Errors = VCAP::Errors

  class FrontController < Sinatra::Base
    register Sinatra::VCAP

    attr_reader :config

    vcap_configure(logger_name: 'cc.api', reload_path: File.dirname(__FILE__))

    def initialize(config, token_decoder)
      @config = config
      @token_decoder = token_decoder
      super()
    end

    before do
      I18n.locale = env['HTTP_ACCEPT_LANGUAGE']

      auth_token = env['HTTP_AUTHORIZATION']
      VCAP::CloudController::Security::SecurityContextConfigurer.new(@token_decoder).configure(auth_token)

      user_guid = VCAP::CloudController::SecurityContext.current_user.nil? ? nil : VCAP::CloudController::SecurityContext.current_user.guid
      logger.info("User for request: #{user_guid}")

      validate_scheme!
    end

    private

    def validate_scheme!
      validator = VCAP::CloudController::RequestSchemeValidator.new
      current_user = VCAP::CloudController::SecurityContext.current_user
      roles = VCAP::CloudController::SecurityContext.roles

      validator.validate!(current_user, roles, @config, request)
    end
  end
end
