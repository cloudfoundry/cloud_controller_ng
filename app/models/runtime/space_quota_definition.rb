module VCAP::CloudController
  class SpaceQuotaDefinition < Sequel::Model
    UNLIMITED = -1

    # Default values
    DEFAULT_NON_BASIC_SERVICES_ALLOWED = true
    DEFAULT_MEMORY_LIMIT = UNLIMITED
    DEFAULT_TOTAL_SERVICES = UNLIMITED
    DEFAULT_TOTAL_ROUTES = UNLIMITED

    RESERVED_PORT_ERROR = Sequel.lit('Total reserved ports must be -1, 0, or a ' \
                                     'positive integer, must be less than or ' \
                                     'equal to total routes, and must be less ' \
                                     'than or equal to total reserved ports for the organization quota.')

    many_to_one :organization, before_set: :validate_change_organization
    one_to_many :spaces

    export_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
      :total_routes, :memory_limit, :instance_memory_limit, :app_instance_limit, :app_task_limit,
      :total_service_keys, :total_reserved_route_ports, :log_rate_limit
    import_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
      :total_routes, :memory_limit, :instance_memory_limit, :app_instance_limit, :app_task_limit,
      :total_service_keys, :total_reserved_route_ports, :log_rate_limit

    add_association_dependencies spaces: :nullify

    def validate
      validates_presence :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :total_routes
      validates_presence :memory_limit
      validates_presence :organization
      validates_unique [:organization_id, :name]

      validates_limit(:memory_limit, memory_limit)
      validates_limit(:instance_memory_limit, instance_memory_limit)
      validates_limit(:app_instance_limit, app_instance_limit)
      validates_limit(:app_task_limit, app_task_limit)
      validates_limit(:log_rate_limit, log_rate_limit)
      validates_limit(:total_service_keys, total_service_keys)

      validate_total_reserved_ports
    end

    def validate_change_organization(new_org)
      raise CloudController::Errors::ApiError.new_from_details('OrganizationAlreadySet') unless organization.nil? || organization.guid == new_org.guid
    end

    def self.user_visibility_filter(user)
      visible_space_ids = user.space_developer_space_ids.
                          union(user.space_manager_space_ids, from_self: false).
                          union(user.space_auditor_space_ids, from_self: false).
                          union(user.space_supporter_space_ids, from_self: false)

      Sequel.or([
        [:id, Space.where(id: visible_space_ids).select(:space_quota_definition_id)],
        [:organization_id, user.org_manager_org_ids]
      ])
    end

    private

    def validates_limit(limit_name, limit)
      errors.add(limit_name, :"invalid_#{limit_name}") if limit && limit < UNLIMITED
    end

    def validate_total_reserved_ports
      return unless total_reserved_route_ports

      if reserved_ports_outside_of_valid_range? ||
          total_reserved_route_ports_greater_than_orgs_ports? ||
          total_reserved_route_ports_greater_than_total_routes?
        errors.add(:total_reserved_route_ports, RESERVED_PORT_ERROR)
      end
    end

    def reserved_ports_outside_of_valid_range?
      total_reserved_route_ports < UNLIMITED
    end

    def total_reserved_route_ports_greater_than_total_routes?
      total_reserved_route_ports > total_routes && total_routes != UNLIMITED
    end

    def total_reserved_route_ports_greater_than_orgs_ports?
      total_reserved_route_ports > organization.quota_definition.total_reserved_route_ports && organization.quota_definition.total_reserved_route_ports != UNLIMITED
    end
  end
end
