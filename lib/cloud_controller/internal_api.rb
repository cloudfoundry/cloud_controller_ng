module VCAP::CloudController
  module InternalApi
    def configure(config)
      @config = config
    end
    module_function :configure

    def credentials
      [
        @config.get(:internal_api, :auth_user),
        @config.get(:internal_api, :auth_password),
      ]
    end
    module_function :credentials
  end
end
