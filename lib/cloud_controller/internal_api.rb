module VCAP::CloudController
  module InternalApi
    def configure(config)
      @config = config[:internal_api]
    end
    module_function :configure

    def credentials
      [
        @config[:auth_user],
        @config[:auth_password],
      ]
    end
    module_function :credentials
  end
end
