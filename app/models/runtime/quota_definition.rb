module VCAP::CloudController
  class QuotaDefinition < Sequel::Model
    UNLIMITED = -1

    # Default values
    DEFAULT_NON_BASIC_SERVICES_ALLOWED = true
    DEFAULT_MEMORY_LIMIT = UNLIMITED
    DEFAULT_TOTAL_SERVICES = UNLIMITED
    DEFAULT_TOTAL_ROUTES = UNLIMITED

    one_to_many :organizations

    export_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
      :total_private_domains, :memory_limit, :trial_db_allowed, :instance_memory_limit,
      :app_instance_limit, :app_task_limit, :total_service_keys, :total_reserved_route_ports,
      :log_rate_limit
    import_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
      :total_private_domains, :memory_limit, :trial_db_allowed, :instance_memory_limit,
      :app_instance_limit, :app_task_limit, :total_service_keys, :total_reserved_route_ports,
      :log_rate_limit

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :total_routes
      validates_presence :memory_limit
      validate_total_reserved_route_ports

      validates_limit(:memory_limit, memory_limit)
      validates_limit(:instance_memory_limit, instance_memory_limit)
      validates_limit(:total_private_domains, total_private_domains)
      validates_limit(:app_instance_limit, app_instance_limit)
      validates_limit(:app_task_limit, app_task_limit)
      validates_limit(:log_rate_limit, log_rate_limit)
      validates_limit(:total_service_keys, total_service_keys)
    end

    def before_destroy
      if organizations.present?
        raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'organization', 'quota definition')
      end
    end

    def trial_db_allowed=(_); end

    def trial_db_allowed
      false
    end

    def self.configure(config)
      @default_quota_name = config.get(:default_quota_definition)
    end

    class << self
      attr_reader :default_quota_name
    end

    def self.default
      self[name: @default_quota_name]
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end

    private

    def validates_limit(limit_name, limit)
      errors.add(limit_name, :"invalid_#{limit_name}") if limit && limit < UNLIMITED
    end

    def validate_total_reserved_route_ports
      return unless total_reserved_route_ports

      err_msg = Sequel.lit('Total reserved ports must be -1, 0, or a positive integer, and must be less than or equal to total routes.')
      route_ports_out_of_range = total_reserved_route_ports < UNLIMITED
      more_ports_than_routes = total_reserved_route_ports > total_routes

      if route_ports_out_of_range || (more_ports_than_routes && total_routes >= 0)
        errors.add(:total_reserved_route_ports, err_msg)
      end
    end
  end
end
