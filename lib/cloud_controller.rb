# Copyright (c) 2009-2012 VMware, Inc.

require "bcrypt"
require "sinatra"
require "sequel"
require "thin"
require "yajl"

require "eventmachine/schedule_sync"

require "vcap/common"
require "uaa/token_coder"

require "sinatra/vcap"
require "cloud_controller/security_context"

module VCAP::CloudController
  autoload :Models, "cloud_controller/models"
  include VCAP::RestAPI

  class Controller < Sinatra::Base
    register Sinatra::VCAP

    vcap_configure(:logger_name => "cc.api",
                   :reload_path => File.dirname(__FILE__))

    def initialize(config)
      @config = config
      super()
    end

    before do
      VCAP::CloudController::SecurityContext.clear
      user = nil
      auth_token = env["HTTP_AUTHORIZATION"]

      if auth_token && auth_token.upcase.start_with?("BEARER")
        token_coder = CF::UAA::TokenCoder.new(@config[:uaa][:resource_id],
                                              @config[:uaa][:symmetric_secret],
                                              nil)
        begin
          token_information = token_coder.decode(auth_token)
          logger.info("Token received from the UAA #{token_information.inspect}")
          uaa_id = token_information[:user_id] if token_information
          user = Models::User.find(:guid => uaa_id) if uaa_id

          # Bootstraping mechanism..
          #
          # TODO: replace this with an exteranl bootstraping mechanism.
          # I'm not wild about having *any* auto-admin generation code
          # in the cc.
          if (user.nil? && Models::User.count == 0 &&
              @config[:bootstrap_admin_email] && token_information[:email] &&
              @config[:bootstrap_admin_email] == token_information[:email])
              user = Models::User.create(:guid => uaa_id,
                                         :admin => true, :active => true)
          end

          VCAP::CloudController::SecurityContext.set(user, token_information)
        rescue => e
          logger.warn("Invalid bearer token: #{e.message} #{e.backtrace}")
        end
      end

      validate_scheme(user)
    end

    def validate_scheme(user)
      return unless user

      if @config[:https_required]
        raise Errors::NotAuthorized unless request.scheme == "https"
      end

      if @config[:https_required_for_admins] && user && user.admin?
        raise Errors::NotAuthorized unless request.scheme == "https"
      end
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
  end
end

require "cloud_controller/config"
require "cloud_controller/db"
require "cloud_controller/errors"
require "cloud_controller/permissions"
require "cloud_controller/runner"
require "cloud_controller/errors"
require "cloud_controller/app_package"
require "cloud_controller/app_stager"
require "cloud_controller/api"

require "cloud_controller/legacy_api/legacy_api_base"
require "cloud_controller/legacy_api/legacy_info"
require "cloud_controller/legacy_api/legacy_apps"
require "cloud_controller/legacy_api/legacy_services"
require "cloud_controller/legacy_api/legacy_service_gateway"
require "cloud_controller/legacy_api/legacy_service_lifecycle"
require "cloud_controller/legacy_api/legacy_bulk"
require "cloud_controller/legacy_api/legacy_staging"
require "cloud_controller/legacy_api/legacy_resources"
require "cloud_controller/legacy_api/legacy_users"

require "cloud_controller/resource_pool/resource_pool"
require "cloud_controller/resource_pool/filesystem_pool"

require "cloud_controller/dea/dea_pool"
require "cloud_controller/dea/dea_client"

require "cloud_controller/health_manager_client"
require "cloud_controller/health_manager_respondent"
