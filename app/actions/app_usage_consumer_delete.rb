module VCAP::CloudController
  class AppUsageConsumerDelete
    def delete(app_usage_consumer)
      app_usage_consumer.destroy
    rescue Sequel::Error => e
      raise CloudController::Errors::ApiError.new_from_details('AppUsageConsumerDeleteError', e.message)
    end
  end
end
