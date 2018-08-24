module VCAP::CloudController
  module InternalApi
    module_function

    def configure(config)
      @config = config
    end

    def credentials
      [
        @config.get(:internal_api, :auth_user),
        @config.get(:internal_api, :auth_password),
      ]
    end
  end
end
