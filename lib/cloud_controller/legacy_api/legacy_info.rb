# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyInfo < LegacyApiBase
    include VCAP::CloudController::Errors

    def info
      info = {
        :name        => config[:info][:name],
        :build       => config[:info][:build],
        :support     => config[:info][:support_address],
        :version     => config[:info][:version],
        :description => config[:info][:description],
        :authorization_endpoint => config[:uaa][:url],
        # TODO: enable once json schema is updated
        # :allow_debug => # config[:allow_debug]
        :allow_debug => false
      }

      # If there is a logged in user, give out additional information
      if user
        info[:user]   = user.guid
        info[:limits] = account_capacity
        info[:usage]  = account_usage
        info[:frameworks] = config[:legacy_framework_manifest]
      end

      Yajl::Encoder.encode(info)
    end

    private

    def account_capacity
      if user.admin?
        Models::AccountCapacity.admin
      else
        Models::AccountCapacity.default
      end
    end

    # TODO: what are the semantics of this?
    def account_usage
      return {} unless default_app_space

      app_num = 0
      app_mem = 0
      default_app_space.apps_dataset.filter(:state => "STARTED").each do |app|
        app_num += 1
        app_mem += (app.memory * app.instances)
      end

      service_count = 0
      {
        :memory => app_mem,
        :apps   => app_num,
        :services => default_app_space.service_instances.count
      }
    end

    def self.setup_routes
      controller.get "/info" do
        LegacyInfo.new(@config, logger, request).info
      end
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    setup_routes
  end
end
