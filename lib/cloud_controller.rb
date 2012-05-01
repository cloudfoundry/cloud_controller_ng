# Copyright (c) 2009-2012 VMware, Inc.

require "bcrypt"
require "sinatra"
require "sequel"
require "thin"
require "yajl"

require "eventmachine/schedule_sync"

require "vcap/common"
require "vcap/concurrency"
require "vcap/logging"

require "sinatra/vcap"

module VCAP
  module CloudController
    autoload :Models, "cloud_controller/models"
    include VCAP::RestAPI

    class Controller < Sinatra::Base
    end
  end
end

require "cloud_controller/config"
require "cloud_controller/db"
require "cloud_controller/runner"
require "cloud_controller/errors"

module VCAP::CloudController
  class Controller < Sinatra::Base
    register Sinatra::VCAP

    vcap_configure :reload_path => File.dirname(__FILE__)

    before do
      auth_token = env['HTTP_AUTHORIZATION']
      if auth_token
        # FIXME: the commented out code is what we used to have.  Now that the
        # UAA is ready to rock, we should just go right to it.  In the mean
        # time, we'll accept a raw email addr just to test different sort of
        # user types using the somewhat correct flow.
        # email = Notary.new(@token_config[:key]).decode(auth_token)
        # @user = Models::User.find(:email => email)
        @user = VCAP::CloudController::Models::User.find(:email => auth_token)
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
        :email => "iliag@vmware.com",
        :password => "not really needed",
        :admin => true,
        :active => true).to_json

      VCAP::RestAPI::HTTP::CREATED
    end
  end
end

require "cloud_controller/api"
