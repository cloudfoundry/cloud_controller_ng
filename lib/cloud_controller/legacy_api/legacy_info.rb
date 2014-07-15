module VCAP::CloudController
  class LegacyInfo < LegacyApiBase
    include VCAP::Errors

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
        :allow_debug => config.fetch(:allow_debug, true)
      }

      # If there is a logged in user, give out additional information
      if user
        info[:user]   = user.guid
        info[:limits] = account_capacity
        info[:usage]  = account_usage if has_default_space?
      end

      MultiJson.dump(info)
    end

    def service_info
      legacy_resp = {}
      Service.filter(:provider => "core").each do |svc|
        next unless svc.service_plans.any? { |plan| plan.name == "100" }

        svc_type = LegacyService.synthesize_service_type(svc)
        legacy_resp[svc_type] ||= {}
        legacy_resp[svc_type][svc.label] ||= {}
        legacy_resp[svc_type][svc.label][svc.version] = legacy_svc_encoding(svc)
      end

      MultiJson.dump(legacy_resp)
    end

    private

    def account_capacity
      if user.admin?
        AccountCapacity.admin
      else
        AccountCapacity.default
      end
    end

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
      get "/info",          :info
      get "/info/services", :service_info
    end

    setup_routes

    deprecated_endpoint("/info")
  end
end
