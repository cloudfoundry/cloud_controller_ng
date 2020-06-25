module VCAP::CloudController
  module ServiceInstanceCreateMixin
    private

    def validate_quotas!(e)
      quota_errors = e.errors.on(:quota).to_a
      plan_errors = e.errors.on(:service_plan).to_a

      code = if quota_errors.include?(:service_instance_space_quota_exceeded)
               'ServiceInstanceSpaceQuotaExceeded'
             elsif quota_errors.include?(:service_instance_quota_exceeded)
               'ServiceInstanceQuotaExceeded'
             elsif plan_errors.include?(:paid_services_not_allowed_by_space_quota)
               'ServiceInstanceServicePlanNotAllowedBySpaceQuota'
             elsif plan_errors.include?(:paid_services_not_allowed_by_quota)
               'ServiceInstanceServicePlanNotAllowed'
             end

      raise VCAP::CloudController::ServiceInstanceCreateManaged::UnprocessableCreate.new_from_details(code) unless code.nil?
    end

    def validation_error!(error, name:)
      validate_quotas!(error)

      if error.errors.on(:name)&.include?(:unique)
        error!("The service instance name is taken: #{name}")
      end
      error!(error.message)
    end
  end
end
