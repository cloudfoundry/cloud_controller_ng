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

    class Controller < Sinatra::Base
    end
  end
end

require "cloud_controller/config"
require "cloud_controller/db"
require "cloud_controller/runner"

module VCAP::CloudController
  class Controller < Sinatra::Base
    register Sinatra::VCAP

    vcap_configure :reload_path => File.dirname(__FILE__)

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
  end
end
