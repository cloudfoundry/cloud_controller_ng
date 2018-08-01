module VCAP::CloudController
  class BitsServiceResourcePoolWrapper
    attr_reader :body

    def initialize(body)
      @body = body
    end

    def call
      bits_service_resource_pool.matches(body.read).body
    rescue BitsService::Errors::Error => e
      raise CloudController::Errors::ApiError.new_from_details('BitsServiceError', e.message)
    end

    def bits_service_resource_pool
      CloudController::DependencyLocator.instance.bits_service_resource_pool
    end
  end
end
