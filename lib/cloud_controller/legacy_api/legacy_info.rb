module VCAP::CloudController
  class LegacyInfo < LegacyApiBase
    include CloudController::Errors

    allow_unauthenticated_access

    get '/info', :info
    def info
      info = {
        name: config.get(:info, :name),
        build: config.get(:info, :build),
        support: config.get(:info, :support_address),
        version: config.get(:info, :version),
        description: config.get(:info, :description),
        authorization_endpoint: config.get(:login) ? config.get(:login, :url) : config.get(:uaa, :url),
        token_endpoint: config.get(:uaa, :url),
        allow_debug: true,
      }

      # If there is a logged in user, give out additional information
      if user
        info[:user]   = user.guid
        info[:limits] = account_capacity
        info[:usage]  = account_usage if has_default_space?
      end

      MultiJson.dump(info)
    end

    private

    def account_capacity
      if user.admin
        AccountCapacity.admin
      else
        AccountCapacity.default
      end
    end

    def account_usage
      return {} unless default_space

      app_num = 0
      app_mem = 0
      default_space.apps_dataset.filter(state: 'STARTED').each do |app|
        app_num += 1
        app_mem += (app.memory * app.instances)
      end

      {
        memory: app_mem,
        apps: app_num,
        services: default_space.service_instances.count
      }
    end

    deprecated_endpoint('/info')
  end
end
