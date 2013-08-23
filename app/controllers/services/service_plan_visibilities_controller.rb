module VCAP::CloudController
  rest_controller :ServicePlanVisibilities do
    define_attributes do
      to_one :service_plan
      to_one :organization
    end

    def self.translate_validation_exception(e, attributes)
      associations_errors = e.errors.on([:organization_id, :service_plan_id])
      if associations_errors && associations_errors.include?(:unique)
        Errors::ServicePlanVisibilityAlreadyExists.new(e.errors.full_messages)
      else
        Errors::ServicePlanVisibilityInvalid.new(e.errors.full_messages)
      end
    end
  end
end
