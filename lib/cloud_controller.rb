# Copyright (c) 2009-2012 VMware, Inc.

require "bcrypt"
require "sinatra"
require "sequel"
require "thin"
require "yajl"

require "eventmachine/schedule_sync"

require "vcap/common"
require "vcap/errors"
require "uaa/token_coder"
require "vcap/uaa_util"

require "sinatra/vcap"
require "cloud_controller/security_context"

module VCAP::CloudController
  autoload :Models, "cloud_controller/models"
  include VCAP::RestAPI

  Errors = VCAP::Errors

  class Controller < Sinatra::Base
    register Sinatra::VCAP
    include VCAP::UaaUtil

    attr_reader :config

    vcap_configure(:logger_name => "cc.api",
                   :reload_path => File.dirname(__FILE__))

    def initialize(config)
      @config = config
      super()
    end

    before do
      VCAP::CloudController::SecurityContext.clear
      auth_token = env["HTTP_AUTHORIZATION"]

      begin
        token_information = decode_token(auth_token)
        logger.info("Token received from the UAA #{token_information.inspect}")

        if token_information
          token_information['user_id'] ||= token_information['client_id']
          uaa_id = token_information['user_id']
        end

        if uaa_id
          user = Models::User.find(:guid => uaa_id)
          user ||= create_admin_if_in_config(token_information)
          user ||= create_admin_if_in_token(token_information)
        end

        VCAP::CloudController::SecurityContext.set(user, token_information)
      rescue => e
        logger.warn("Invalid bearer token: #{e.message} #{e.backtrace}")
      end

      validate_scheme(user, VCAP::CloudController::SecurityContext.current_user_is_admin?)
    end

    # All manual routes here will be removed prior to final release.
    # They are manual ad-hoc testing entry points.
    get "/hello/sync" do
      "sync return\n"
    end

    get "/hello/async" do
      sleep 5
      "async return\n"
    end

    get "/hello/em_sync" do
      EM.schedule_sync do
        "async return from the EM thread\n"
      end
    end

    get "/hello/em_async" do
      EM.schedule_sync do |promise|
        EM::Timer.new(5) { promise.deliver("async return from an EM timer\n") }
      end
    end

    private

    def validate_scheme(user, admin)
      return unless user || admin

      if @config[:https_required]
        raise Errors::NotAuthorized unless request.scheme == "https"
      end

      if @config[:https_required_for_admins] && admin
        raise Errors::NotAuthorized unless request.scheme == "https"
      end
    end

    def create_admin_if_in_config(token_information)
      if Models::User.count == 0 && current_user_admin?(token_information)
        Models::User.create(:guid => token_information['user_id'], :admin => true, :active => true)
      end
    end

    def create_admin_if_in_token(token_information)
      if VCAP::CloudController::Roles.new(token_information).admin?
        Models::User.create(:guid => token_information['user_id'], :admin => true, :active => true)
      end
    end

    def current_user_admin?(token_information)
      admin_email = config[:bootstrap_admin_email]
      admin_email && (admin_email == token_information['email'])
    end
  end
end

require "vcap/errors"

require "cloud_controller/config"
require "cloud_controller/db"
require "cloud_controller/permissions"
require "cloud_controller/runner"
require "cloud_controller/app_package"
require "cloud_controller/app_stager"
require "cloud_controller/stager_pool"
require "cloud_controller/api"
require "cloud_controller/roles"

require "cloud_controller/legacy_api/legacy_api_base"
require "cloud_controller/legacy_api/legacy_info"
require "cloud_controller/legacy_api/legacy_apps"
require "cloud_controller/legacy_api/legacy_services"
require "cloud_controller/legacy_api/legacy_service_gateway"
require "cloud_controller/legacy_api/legacy_bulk"
require "cloud_controller/legacy_api/legacy_staging"
require "cloud_controller/legacy_api/legacy_resources"
require "cloud_controller/legacy_api/legacy_users"

require "cloud_controller/resource_pool"

require "cloud_controller/dea/dea_pool"
require "cloud_controller/dea/dea_client"

require "cloud_controller/health_manager_client"
require "cloud_controller/health_manager_respondent"
