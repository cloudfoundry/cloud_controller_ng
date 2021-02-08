require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module ServiceInstanceCreateMixin
    class UnprocessableOperation < CloudController::Errors::ApiError
    end

    private

    def validate_quotas!(errors)
      quota_errors = errors.on(:quota).to_a
      plan_errors = errors.on(:service_plan).to_a

      code = if quota_errors.include?(:service_instance_space_quota_exceeded)
               'ServiceInstanceSpaceQuotaExceeded'
             elsif quota_errors.include?(:service_instance_quota_exceeded)
               'ServiceInstanceQuotaExceeded'
             elsif plan_errors.include?(:paid_services_not_allowed_by_space_quota)
               'ServiceInstanceServicePlanNotAllowedBySpaceQuota'
             elsif plan_errors.include?(:paid_services_not_allowed_by_quota)
               'ServiceInstanceServicePlanNotAllowed'
             end

      raise UnprocessableOperation.new_from_details(code) unless code.nil?
    end

    def validation_error!(
      exception,
      name:,
      validation_error_handler:
    )
      errors = exception.errors
      validate_quotas!(errors)

      if errors.on(:name)&.include?(:unique)
        validation_error_handler.error!("The service instance name is taken: #{name}.")
      end

      validation_error_handler.error!(exception.message)
    end
  end
end
