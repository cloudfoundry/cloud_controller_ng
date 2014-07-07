module VCAP::CloudController
  module BulkApi
    def configure(config)
      @config = config[:bulk_api]
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
