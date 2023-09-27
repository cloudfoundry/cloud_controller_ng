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
      return if route.host.blank?

      route.errors.add(:host, :host_and_path_domain_tcp)
    end

    def validate_path_not_included
      return if route.path.blank?

      route.errors.add(:path, :host_and_path_domain_tcp)
    end

    def validate_path_not_included_for_internal_domain
      return unless !route.domain.nil? && route.domain.internal && route.path.present?

      route.errors.add(:path, :path_not_supported_for_internal_domain)
    end

    def validate_wildcard_host_not_included_with_internal_domain
      return unless !route.domain.nil? && route.domain.internal && route.wildcard_host?

      route.errors.add(:host, :wildcard_host_not_supported_for_internal_domain)
    end

    def validate_port_included
      return unless route.port.nil?

      route.errors.add(:port, :port_required)
    end

    def validate_port_not_included
      return unless route.port.present?

      route.errors.add(:port, :port_unsupported)
    end

    def validate_port_number
      return unless route.port && router_group.reservable_ports.exclude?(route.port)

      route.errors.add(:port, :port_unavailable)
    end

    def validate_port_not_taken
      return unless port_taken?

      route.errors.add(:port, :port_taken)
    end

    def port_taken?
      Route.
        join(:domains, id: :domain_id).
        where(domains__router_group_guid: route.domain.router_group_guid,
              routes__port: route.port).
        any?
    end
  end
end
