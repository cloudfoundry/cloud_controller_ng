module VCAP::CloudController
  class SpaceQuotaDefinition < Sequel::Model
    class OrganizationAlreadySet < RuntimeError; end

    many_to_one :organization, before_set: :validate_change_organization
    one_to_many :spaces

    export_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
      :total_routes, :memory_limit, :instance_memory_limit
    import_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
      :total_routes, :memory_limit, :instance_memory_limit

    add_association_dependencies spaces: :nullify

    def validate
      validates_presence :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :total_routes
      validates_presence :memory_limit
      validates_presence :organization
      validates_unique [:organization_id, :name]

      errors.add(:memory_limit, :less_than_zero) if memory_limit && memory_limit < 0
      errors.add(:instance_memory_limit, :invalid_instance_memory_limit) if instance_memory_limit && instance_memory_limit < -1
    end

    def validate_change_organization(new_org)
      raise OrganizationAlreadySet unless organization.nil? || organization.guid == new_org.guid
    end

    def self.user_visibility_filter(user)
      Sequel.or([
        [:organization, user.managed_organizations_dataset],
        [:spaces, user.spaces_dataset],
        [:spaces, user.managed_spaces_dataset],
        [:spaces, user.audited_spaces_dataset]
      ])
    end
  end
end
