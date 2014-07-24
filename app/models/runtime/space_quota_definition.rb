module VCAP::CloudController
  class SpaceQuotaDefinition < Sequel::Model
    many_to_one :organization

    export_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
      :total_routes, :memory_limit
    import_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
      :total_routes, :memory_limit

    def validate
      validates_presence :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :total_routes
      validates_presence :memory_limit
      validates_presence :organization
      validates_unique [:organization_id, :name]
    end

    def self.user_visibility_filter(user)
      Sequel.or(
        organization: user.managed_organizations_dataset
      )
    end
  end
end
