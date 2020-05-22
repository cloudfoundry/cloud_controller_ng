module VCAP::CloudController
  class RouteValidator
    class ValidationError < StandardError; end
    class DomainInvalid < ValidationError; end
    class RouteInvalid < ValidationError; end
    class RoutePortTaken < ValidationError; end

    attr_reader :route

    def initialize(route)
      @route = route
    end

    def validate
      validate_router_group
      validate_path_not_included_for_internal_domain
      validate_wildcard_host_not_included_with_internal_domain
      if domain_protocols&.include?('tcp')
        validate_host_not_included
        validate_path_not_included
        validate_port_included
        validate_port_not_taken if route.new? || route.modified?(:port)
        validate_port_number
      else
        validate_port_not_included
      end
    end

    private

    def domain_has_router_group_guid?
      !route.domain.nil? && route.domain.shared? && !route.domain.router_group_guid.nil?
    end

    def domain_protocols
      route.domain&.protocols
    end

    def router_group
      route.domain.router_group
    end

    def validate_router_group
      route.errors.add(:router_group, route.domain.router_group_guid.to_s) if domain_has_router_group_guid? && router_group.nil?
    end

    def validate_host_not_included
      unless route.host.blank?
        route.errors.add(:host, :host_and_path_domain_tcp)
      end
    end

    def validate_path_not_included
      unless route.path.blank?
        route.errors.add(:path, :host_and_path_domain_tcp)
      end
    end

    def validate_path_not_included_for_internal_domain
      if !route.domain.nil? && route.domain.internal && route.path.present?
        route.errors.add(:path, :path_not_supported_for_internal_domain)
      end
    end

    def validate_wildcard_host_not_included_with_internal_domain
      if !route.domain.nil? && route.domain.internal && route.wildcard_host?
        route.errors.add(:host, :wildcard_host_not_supported_for_internal_domain)
      end
    end

    def validate_port_included
      if route.port.nil?
        route.errors.add(:port, :port_required)
      end
    end

    def validate_port_not_included
      if route.port.present?
        route.errors.add(:port, :port_unsupported)
      end
    end

    def validate_port_number
      if route.port && router_group.reservable_ports.exclude?(route.port)
        route.errors.add(:port, :port_unavailable)
      end
    end

    def validate_port_not_taken
      if port_taken?
        route.errors.add(:port, :port_taken)
      end
    end

    def port_taken?
      domains = Route.dataset.select_all(Route.table_name).
                join(Domain.table_name, id: :domain_id).
                where("#{Domain.table_name}__router_group_guid": route.domain.router_group_guid,
                      "#{Route.table_name}__port": route.port)

      domains.count > 0
    end
  end
end
