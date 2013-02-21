# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyInfo < LegacyApiBase
    include VCAP::CloudController::Errors

    allow_unauthenticated_access

    def info
      info = {
        :name        => config[:info][:name],
        :build       => config[:info][:build],
        :support     => config[:info][:support_address],
        :version     => config[:info][:version],
        :description => config[:info][:description],
        :authorization_endpoint => config[:login] ? config[:login][:url] : config[:uaa][:url],
        :token_endpoint => config[:uaa][:url],
        :allow_debug => config[:allow_debug] || true,
        # TODO get this from DB
        :frameworks  => legacy_framework_info
      }

      # If there is a logged in user, give out additional information
      if user
        info[:user]   = user.guid
        info[:limits] = account_capacity
        info[:usage]  = account_usage if has_default_space?
        info[:frameworks] = legacy_framework_info
      end

      Yajl::Encoder.encode(info)
    end

    def service_info
      # TODO: narrow down the subset to expose to unauthenticated users
      # raise NotAuthenticated unless user

      legacy_resp = {}
      Models::Service.filter(:provider => "core").each do |svc|
        next unless svc.service_plans.any? { |plan| plan.name == "100" }

        svc_type = LegacyService.synthesize_service_type(svc)
        legacy_resp[svc_type] ||= {}
        legacy_resp[svc_type][svc.label] ||= {}
        legacy_resp[svc_type][svc.label][svc.version] = legacy_svc_encoding(svc)
      end

      Yajl::Encoder.encode(legacy_resp)
    end

    def runtime_info
      rt_info = Models::Runtime.all.inject({}) do |result, runtime|
        result.merge(runtime.name => {
          :version => runtime.internal_info["version"],
          :description => runtime.description,
          :debug_modes=> runtime.internal_info["debug_modes"],
        })
      end

      Yajl::Encoder.encode(rt_info)
    end

    private

    def account_capacity
      if user.admin?
        AccountCapacity.admin
      else
        AccountCapacity.default
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

    # this is a direct port of the legacy cc info.
    def legacy_framework_info
      frameworks_info = {}
      Models::Framework.each do |framework|
        runtimes = []

        framework.internal_info["runtimes"].each do |runtime|
          runtime.keys.each do |runtime_name|
            runtime = Models::Runtime[:name => runtime_name]
            if runtime
              runtimes <<  {
                :name => runtime_name,
                :description => runtime.description,
                :version => runtime.internal_info["version"],
              }
            else
              logger.warn(
                "Manifest for #{framework.name} lists a runtime not " +
                "present in runtimes.yml: #{runtime_name}. " +
                "Runtime will be skipped."
              )
            end
          end
        end
        frameworks_info[framework.name] = {
          :name => framework.name,
          :runtimes => runtimes,
          :detection => framework.internal_info["detection"],
        }
      end
      frameworks_info
    end

    def self.setup_routes
      get "/info",          :info
      get "/info/runtimes", :runtime_info
      get "/info/services", :service_info
    end

    setup_routes
  end
end
