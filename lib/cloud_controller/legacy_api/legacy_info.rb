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

    def service_info
      raise NotAuthenticated unless user

      ds = Models::Service.user_visible

      legacy_resp = {}
      ds.filter(:provider => "core").each do |svc|
        svc_type = LegacyService.synthesize_service_type(svc)
        legacy_resp[svc_type] ||= {}
        legacy_resp[svc_type][svc.label] ||= {}
        legacy_resp[svc_type][svc.label][svc.version] = legacy_svc_encoding(svc)
      end

      Yajl::Encoder.encode(legacy_resp)
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
      return {} unless default_space

      app_num = 0
      app_mem = 0
      default_space.apps_dataset.filter(:state => "STARTED").each do |app|
        app_num += 1
        app_mem += (app.memory * app.instances)
      end

      service_count = 0
      {
        :memory => app_mem,
        :apps   => app_num,
        :services => default_space.service_instances.count
      }
    end

    def legacy_svc_encoding(svc)
      {
        :id      => svc.guid,
        :vendor  => svc.label,
        :version => svc.version,
        :type    => LegacyService.synthesize_service_type(svc),
        :description => svc.description || "-",

        # The legacy vmc/sts clients only handles free.  Don't
        # try to pretent otherwise.
        :tiers => {
          "free" => {
            "options" => { },
            "order" => 1
          }
        }
      }
    end

    def self.setup_routes
      controller.get "/info" do
        LegacyInfo.new(@config, logger).info
      end

      controller.get "/info/services" do
        LegacyInfo.new(@config, logger).service_info
      end
    end

    setup_routes
  end
end
