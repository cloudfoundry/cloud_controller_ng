require 'cloud_controller/uaa/uaa_client'

module VCAP::CloudController
  class ServiceAccountClient < UaaClient
    def get(type, id)
      raise ArgumentError.new('only client resources are supported') unless type == :client

      super
    end

    def add(type, registration)
      raise ArgumentError.new('only client resources are supported') unless type == :client

      with_cache_retry { scim.add(type, registration) }
    end
  end
end
