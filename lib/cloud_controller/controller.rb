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
      VCAP::CloudController::SecurityContext.clear
      auth_token = env["HTTP_AUTHORIZATION"]

      token_information = decode_token(auth_token)

      if token_information
        token_information['user_id'] ||= token_information['client_id']
        uaa_id = token_information['user_id']
      end

      if uaa_id
        user = User.find(:guid => uaa_id.to_s)
        user ||= User.create(guid: token_information['user_id'], admin: current_user_admin?(token_information), active: true)
      end

      VCAP::CloudController::SecurityContext.set(user, token_information)

      validate_scheme(user, VCAP::CloudController::SecurityContext.admin?)
    end

    get "/hello/sync" do
      "sync return\n"
    end

    private

    def decode_token(auth_token)
      token_information = @token_decoder.decode_token(auth_token)
      logger.info("Token received from the UAA #{token_information.inspect}")
      token_information
    rescue CF::UAA::TokenExpired
      logger.info('Token expired')
    rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
      logger.warn("Invalid bearer token: #{e.inspect} #{e.backtrace}")
    end

    def validate_scheme(user, admin)
      return unless user || admin

      if @config[:https_required]
        raise Errors::ApiError.new_from_details("NotAuthorized") unless request.scheme == "https"
      end

      if @config[:https_required_for_admins] && admin
        raise Errors::ApiError.new_from_details("NotAuthorized") unless request.scheme == "https"
      end
    end

    def current_user_admin?(token_information)
      if User.count.zero?
        admin_email = config[:bootstrap_admin_email]
        admin_email && (admin_email == token_information['email'])
      else
        VCAP::CloudController::Roles.new(token_information).admin?
      end
    end
  end
end