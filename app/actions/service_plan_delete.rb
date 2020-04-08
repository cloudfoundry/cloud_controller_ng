module VCAP::CloudController
  class ServicePlanDelete
    class AssociationNotEmptyError < StandardError; end

    def delete(service_plan_model)
      association_not_empty! unless service_plan_model.service_instances.empty?
      service_plan_model.destroy
    end

    private

    def association_not_empty!
      raise AssociationNotEmptyError.new('Please delete the service_instances associations for your service_plans.')
    end
  end
end
