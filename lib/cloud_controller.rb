# Copyright (c) 2009-2012 VMware, Inc.

require "bcrypt"
require "sinatra"
require "sequel"
require "thin"
require "yajl"
# require "yaml"

require "allowy"

require "eventmachine/schedule_sync"

require "vcap/common"
require "vcap/errors"
require "uaa/token_coder"

require "sinatra/vcap"
require "cloud_controller/security_context"
require "active_support/core_ext/hash"
require "active_support/json/encoding"

module VCAP::CloudController
  autoload :Models, "cloud_controller/models"
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
        user = Models::User.find(:guid => uaa_id.to_s)
        user ||= Models::User.create(guid: token_information['user_id'], admin: current_user_admin?(token_information), active: true)
      end

      VCAP::CloudController::SecurityContext.set(user, token_information)

      validate_scheme(user, VCAP::CloudController::SecurityContext.current_user_is_admin?)
    end

    # TODO: remove from usage in cloud_controller_spec.rb
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
        raise Errors::NotAuthorized unless request.scheme == "https"
      end

      if @config[:https_required_for_admins] && admin
        raise Errors::NotAuthorized unless request.scheme == "https"
      end
    end

    def current_user_admin?(token_information)
      if Models::User.count.zero?
        admin_email = config[:bootstrap_admin_email]
        admin_email && (admin_email == token_information['email'])
      else
        VCAP::CloudController::Roles.new(token_information).admin?
      end
    end
  end
end

require "vcap/errors"

require "cloud_controller/config"
require "cloud_controller/db"
require "cloud_controller/permissions"
require "cloud_controller/runner"
require "cloud_controller/app_package"
require "cloud_controller/app_manager"
require "cloud_controller/app_stager_task"
require "cloud_controller/stager_pool"
require "cloud_controller/controllers"
require "cloud_controller/roles"
require "cloud_controller/encryptor"
require "cloud_controller/blob_store/blob_store"
require "cloud_controller/dependency_locator"
require "cloud_controller/controller_factory"

require "cloud_controller/legacy_api/legacy_api_base"
require "cloud_controller/legacy_api/legacy_info"
require "cloud_controller/legacy_api/legacy_services"
require "cloud_controller/legacy_api/legacy_service_gateway"
require "cloud_controller/legacy_api/legacy_bulk"

require "cloud_controller/resource_pool"

require "cloud_controller/dea/dea_pool"
require "cloud_controller/dea/dea_client"
require "cloud_controller/dea/dea_respondent"

require "cloud_controller/health_manager_client"
require "cloud_controller/health_manager_respondent"

require "cloud_controller/task_client"
