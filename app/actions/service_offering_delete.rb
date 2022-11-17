module VCAP::CloudController
  class ServiceOfferingDelete
    class AssociationNotEmptyError < StandardError; end

    def delete(service_offering_model)
      association_not_empty! if ServicePlan.where(service_id: service_offering_model.id).any?
      service_offering_model.destroy
    end

    private

    def association_not_empty!
      raise AssociationNotEmptyError.new('Please delete the service_plans associations for your services.')
    end
  end
end
