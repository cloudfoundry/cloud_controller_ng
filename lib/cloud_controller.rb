# Copyright (c) 2009-2012 VMware, Inc.

require "bcrypt"
require "sinatra"
require "sequel"
require "thin"
require "yajl"

require "eventmachine/schedule_sync"

require "vcap/common"
require "vcap/logging"
require "uaa/token_coder"

require "sinatra/vcap"

module VCAP::CloudController
  autoload :Models, "cloud_controller/models"
  include VCAP::RestAPI

  class Controller < Sinatra::Base
    register Sinatra::VCAP

    vcap_configure :reload_path => File.dirname(__FILE__)

    def initialize(config)
      @config = config
      super()
    end

    before do
      auth_token = env["HTTP_AUTHORIZATION"]
      if auth_token
        token_coder = CF::UAA::TokenCoder.new(@config[:uaa][:resource_id],
                                              @config[:uaa][:symetric_secret],
                                              nil)
        begin
          token_information = token_coder.decode(auth_token)
          logger.info("Token received from the UAA #{token_information.inspect}")
          uaa_id = token_information[:user_id] if token_information
          @user = Models::User.find(:id => uaa_id) if uaa_id
        rescue => e
          logger.error("Invalid bearer token Message: #{e.message}")
        end
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
      EM.schedule_sync do |callback|
        EM::Timer.new(5) { callback.call("async return from an EM timer\n") }
      end
    end

    # This is is temporary for ilia
    get "/bootstrap" do
      body VCAP::CloudController::Models::User.create_from_hash(
        :id => "iliag@vmware.com",
        :admin => true,
        :active => true).to_json

      VCAP::RestAPI::HTTP::CREATED
    end
  end
end

require "cloud_controller/config"
require "cloud_controller/db"
require "cloud_controller/errors"
require "cloud_controller/permissions"
require "cloud_controller/runner"
require "cloud_controller/errors"
require "cloud_controller/api"
