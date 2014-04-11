require 'cloud_controller/security/security_context_configurer'

module VCAP::CloudController
  include VCAP::RestAPI

  Errors = VCAP::Errors

  class Controller < Sinatra::Base
    register Sinatra::VCAP

    attr_reader :config

    vcap_configure(logger_name: "cc.api", reload_path: File.dirname(__FILE__))

    def initialize(config, token_decoder)
      @config = config
      @token_decoder = token_decoder
      super()
    end

    before do
      auth_token = env["HTTP_AUTHORIZATION"]

      VCAP::CloudController::Security::SecurityContextConfigurer.new(@token_decoder).configure(auth_token)

      validate_scheme
    end

    get "/hello/sync" do
      "sync return\n"
    end

    private

    def validate_scheme
      user = VCAP::CloudController::SecurityContext.current_user
      admin = VCAP::CloudController::SecurityContext.admin?
      return unless user || admin

      if @config[:https_required]
        raise Errors::ApiError.new_from_details("NotAuthorized") unless request.scheme == "https"
      end

      if @config[:https_required_for_admins] && admin
        raise Errors::ApiError.new_from_details("NotAuthorized") unless request.scheme == "https"
      end
    end
  end
end