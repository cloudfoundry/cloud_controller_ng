module VCAP::CloudController
  class ServicePlanVisibility < Sequel::Model
    many_to_one :service_plan
    many_to_one :organization

    import_attributes :service_plan_guid, :organization_guid
    export_attributes :service_plan_guid, :organization_guid

    def validate
      validates_presence :service_plan
      validates_presence :organization
      validates_unique [:organization_id, :service_plan_id]
      validate_plan_is_not_private
    end

    def self.visible_private_plan_ids_for_user(user)
      user.organizations.map {|org|
        visible_private_plan_ids_for_organization(org)
      }.flatten.uniq
    end

    def self.visible_private_plan_ids_for_organization(organization)
      organization.service_plan_visibilities.map(&:service_plan_id)
    end

    private

    def validate_plan_is_not_private
      if service_plan && service_plan.broker_private?
        errors.add(:service_plan, 'is from a private broker')
      end
    end
  end
end
