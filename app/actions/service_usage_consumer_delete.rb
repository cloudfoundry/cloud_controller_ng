module VCAP::CloudController
  class ServiceUsageConsumerDelete
    def delete(service_usage_consumer)
      service_usage_consumer.destroy
    rescue Sequel::Error => e
      raise CloudController::Errors::ApiError.new_from_details('ServiceUsageConsumerDeleteError', e.message)
    end
  end
end
