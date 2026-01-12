require 'utils/uri_utils'
require 'models/helpers/process_types'
require 'cloud_controller/routing_api/disabled_routing_api_client'
require 'cloud_controller/route_validator'
require 'actions/services/route_binding_delete'

module VCAP::CloudController
  class Route < Sequel::Model
    class InvalidOrganizationRelation < CloudController::Errors::InvalidRelation; end

    many_to_one :domain
    many_to_one :space, after_set: :validate_changed_space
    one_through_one :organization, join_table: Space.table_name, left_key: :id, left_primary_key: :space_id, right_primary_key: :id, right_key: :organization_id

    one_to_many :route_mappings, class: 'VCAP::CloudController::RouteMappingModel', key: :route_guid, primary_key: :guid
    one_to_many :labels, class: 'VCAP::CloudController::RouteLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::RouteAnnotationModel', key: :resource_guid, primary_key: :guid

    # TODO: apps are actually processes
    many_to_many :apps, class: 'VCAP::CloudController::ProcessModel',
                        join_table: RouteMappingModel.table_name,
                        left_primary_key: :guid, left_key: :route_guid,
                        right_primary_key: %i[app_guid type], right_key: %i[app_guid process_type],
                        distinct: true,
                        order: Sequel.asc(:id),
                        conditions: { type: ProcessTypes::WEB }

    many_to_many :shared_spaces,
                 left_key: :route_guid,
                 left_primary_key: :guid,
                 right_key: :target_space_guid,
                 right_primary_key: :guid,
                 join_table: :route_shares,
                 class: VCAP::CloudController::Space,
                 ignored_unique_constraint_violation_errors: %w[route_shares.PRIMARY route_target_space_pk]

    one_to_one :route_binding
    one_through_one :service_instance, join_table: :route_bindings

    add_association_dependencies route_mappings: :destroy

    export_attributes :host, :path, :domain_guid, :space_guid, :service_instance_guid, :port, :options
    import_attributes :host, :path, :domain_guid, :space_guid, :app_guids, :port, :options

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    def shared?
      VCAP::CloudController::Space.where(routes_shared_from_other_spaces: self).empty? == false
    end

    def fqdn
      host.empty? ? domain.name : "#{host}.#{domain.name}"
    end

    def uri
      "#{fqdn}#{path}#{":#{port}" unless port.nil?}"
    end

    def as_summary_json
      {
        guid: guid,
        host: host,
        port: port,
        path: path,
        domain: {
          guid: domain.guid,
          name: domain.name
        }
      }
    end

    def options_with_serialization=(opts)
      cleaned_opts = remove_hash_options_for_non_hash_loadbalancing(opts)
      rounded_opts = round_hash_balance_to_one_decimal(cleaned_opts)
      normalized_opts = normalize_hash_balance_to_string(rounded_opts)
      # Remove nil values after all processing
      normalized_opts = normalized_opts.compact if normalized_opts.is_a?(Hash)
      self.options_without_serialization = Oj.dump(normalized_opts)
    end

    alias_method :options_without_serialization=, :options=
    alias_method :options=, :options_with_serialization=

    def options_with_serialization
      string = options_without_serialization
      return nil if string.blank?

      Oj.load(string)
    end

    alias_method :options_without_serialization, :options
    alias_method :options, :options_with_serialization

    alias_method :old_path, :path
    def path
      old_path.nil? ? '' : old_path
    end

    def port
      super == 0 ? nil : super
    end

    def organization
      space.organization if space
    end

    def route_service_url
      route_binding && route_binding.route_service_url
    end

    def validate
      validates_presence :domain
      validates_presence :space

      errors.add(:host, :presence) if host.nil?

      validates_format(/\A([\w-]+|\*)\z/, :host) if host && !host.empty?

      validate_uniqueness_on_host_and_domain if path.empty? && port.nil?
      validate_uniqueness_on_host_domain_and_port if path.empty?
      validate_uniqueness_on_host_domain_and_path if port.nil?

      validate_host_and_domain_in_different_space
      validate_host_and_domain
      validate_host
      validate_fqdn
      validate_path
      validate_domain
      validate_total_routes
      validate_ports
      validate_total_reserved_route_ports if port && port > 0
      validate_route_options

      RouteValidator.new(self).validate
    rescue RoutingApi::UaaUnavailable
      errors.add(:routing_api, :uaa_unavailable)
    rescue RoutingApi::RoutingApiUnavailable
      errors.add(:routing_api, :routing_api_unavailable)
    rescue RoutingApi::RoutingApiDisabled
      errors.add(:routing_api, :routing_api_disabled)
    end

    def validate_host_and_domain
      return unless domain

      domain_is_system_domain = domain.name == Config.config.get(:system_domain)
      host_is_system_hostname = Config.config.get(:system_hostnames).include? host

      errors.add(:host, :system_hostname_conflict) if domain_is_system_domain && host_is_system_hostname
      errors.add(:host, :domain_conflict) if domains_match?
    end

    def validate_ports
      return unless port

      errors.add(:port, :invalid_port) if port < 0 || port > 65_535
    end

    def validate_path
      return if path == ''

      errors.add(:path, :invalid_path) unless UriUtils.is_uri?("pathcheck://#{host}#{path}")

      errors.add(:path, :single_slash) if path == '/'

      errors.add(:path, :missing_beginning_slash) if path[0] != '/'

      errors.add(:path, :path_contains_question) if path.match?(/\?/)

      return unless path.length > 128

      errors.add(:path, :path_exceeds_valid_length)
    end

    def domains_match?
      return false if domain.nil? || host.nil? || host.empty?

      !Domain.find(name: fqdn).nil?
    end

    def validate_changed_space(new_space)
      raise CloudController::Errors::InvalidAppRelation.new('Route and apps not in same space') if !FeatureFlag.enabled?(:route_sharing) && apps.any? do |app|
                                                                                                     app.space.id != space.id
                                                                                                   end
      raise InvalidOrganizationRelation.new("Organization cannot use domain #{domain.name}") if domain && !domain.usable_by_organization?(new_space.organization)
    end

    def self.user_visibility_filter(user)
      {
        space_id: user.space_developer_space_ids.
          union(user.space_manager_space_ids, from_self: false).
          union(user.space_auditor_space_ids, from_self: false).
          union(user.space_supporter_space_ids, from_self: false).
          union(Space.join(user.org_manager_org_ids, organization_id: :organization_id).select(:spaces__id)).
          union(Space.join(user.org_auditor_org_ids, organization_id: :organization_id).select(:spaces__id)).
          select(:space_id)
      }
    end

    def available_in_space?(other_space)
      other_space == space || shared_spaces.include?(other_space)
    end

    delegate :in_suspended_org?, to: :space

    def tcp?
      domain.shared? && domain.tcp? && port.present? && port > 0
    end

    def protocol
      domain.protocols.first
    end

    def internal?
      domain.internal
    end

    def wildcard_host?
      host == '*'
    end

    private

    def before_destroy
      destroy_route_bindings
      super
    end

    def destroy_route_bindings
      errors = RouteBindingDelete.new.delete(route_binding_dataset)

      quoted_table_name = RouteBinding.db.quote_identifier(RouteBinding.table_name)
      errors.reject! { |e| e.is_a?(Sequel::NoExistingObject) && e.message.include?("DELETE FROM #{quoted_table_name}") }

      raise errors.first unless errors.empty?
    end

    def around_destroy
      loaded_apps = apps
      super

      loaded_apps.each do |app|
        ProcessRouteHandler.new(app).notify_backend_of_route_update
      end
    end

    def validate_host_and_domain_in_different_space
      return unless space
      return unless domain
      return if domain.private? && private_domain_cross_space_context_path_route_sharing_enabled?

      validates_unique [:domain_id, :host], message: :host_and_domain_taken_different_space do |ds|
        ds.where(port: 0).exclude(space:)
      end
    end

    def private_domain_cross_space_context_path_route_sharing_enabled?
      !Config.config.get(:disable_private_domain_cross_space_context_path_route_sharing)
    end

    def validate_host
      return unless host && host.length > Domain::MAXIMUM_DOMAIN_LABEL_LENGTH

      errors.add(:host, "must be no more than #{Domain::MAXIMUM_DOMAIN_LABEL_LENGTH} characters")
    end

    def validate_fqdn
      return unless host

      length_with_period_separator = host.length + 1
      host_label_length = host.empty? ? 0 : length_with_period_separator
      total_domain_too_long = host_label_length + domain.name.length > Domain::MAXIMUM_FQDN_DOMAIN_LENGTH
      errors.add(:host, "combined with domain name must be no more than #{Domain::MAXIMUM_FQDN_DOMAIN_LENGTH} characters") if total_domain_too_long
    end

    def validate_domain
      errors.add(:domain, :invalid_relation) unless valid_domain
      errors.add(:host, 'is required for shared-domains') if domain && domain.shared? && !domain.tcp? && host.blank?
    end

    def valid_domain
      return false if domain.nil?

      domain_change = column_change(:domain_id)
      return false if !new? && domain_change && domain_change[0] != domain_change[1]

      return false if space && !domain.usable_by_organization?(space.organization) # domain is not usable by the org

      true
    end

    def validate_total_routes
      return unless new? && space

      space_routes_policy = MaxRoutesPolicy.new(space.space_quota_definition, SpaceRoutes.new(space))
      org_routes_policy   = MaxRoutesPolicy.new(space.organization.quota_definition, OrganizationRoutes.new(space.organization))

      errors.add(:space, :total_routes_exceeded) if space.space_quota_definition && !space_routes_policy.allow_more_routes?(1)

      return if org_routes_policy.allow_more_routes?(1)

      errors.add(:organization, :total_routes_exceeded)
    end

    def validate_total_reserved_route_ports
      return unless new? && space

      org_route_port_counter = OrganizationReservedRoutePorts.new(space.organization)
      org_quota_definition = space.organization.quota_definition
      org_reserved_route_ports_policy = MaxReservedRoutePortsPolicy.new(org_quota_definition, org_route_port_counter)

      space_quota_definition = space.space_quota_definition

      if space_quota_definition.present?
        space_route_port_counter = SpaceReservedRoutePorts.new(space)
        space_reserved_route_ports_policy = MaxReservedRoutePortsPolicy.new(space_quota_definition, space_route_port_counter)
        errors.add(:space, :total_reserved_route_ports_exceeded) unless space_reserved_route_ports_policy.allow_more_route_ports?
      end

      return if org_reserved_route_ports_policy.allow_more_route_ports?

      errors.add(:organization, :total_reserved_route_ports_exceeded)
    end

    def validate_route_options
      return if options.blank?

      route_options = options.is_a?(Hash) ? options : options.symbolize_keys
      loadbalancing = route_options[:loadbalancing] || route_options['loadbalancing']

      return if loadbalancing != 'hash'

      hash_header = route_options[:hash_header] || route_options['hash_header']

      return if hash_header.present?

      errors.add(:route, :hash_header_missing)
    end

    def round_hash_balance_to_one_decimal(opts)
      return opts unless opts.is_a?(Hash)

      opts_symbolized = opts.symbolize_keys
      hash_balance = opts_symbolized[:hash_balance]

      if hash_balance.present?
        begin
          balance_float = Float(hash_balance)
          # Round to at most 1 decimal place
          opts_symbolized[:hash_balance] = (balance_float * 10).round / 10.0
        rescue ArgumentError, TypeError
          # If conversion fails, leave it as is - validation will catch it
        end
      end

      opts_symbolized
    end

    def normalize_hash_balance_to_string(opts)
      return opts unless opts.is_a?(Hash)

      # We have a flat structure on options, so no deep_symbolize required
      normalized = opts.symbolize_keys
      normalized[:hash_balance] = normalized[:hash_balance].to_s if normalized[:hash_balance].present?
      normalized
    end

    def remove_hash_options_for_non_hash_loadbalancing(opts)
      return opts unless opts.is_a?(Hash)

      opts_symbolized = opts.symbolize_keys
      loadbalancing = opts_symbolized[:loadbalancing]

      # Remove hash-specific options if loadbalancing is set to non-hash value
      if loadbalancing != 'hash'
        opts_symbolized.delete(:hash_header)
        opts_symbolized.delete(:hash_balance)
      end

      opts_symbolized
    end

    def validate_uniqueness_on_host_and_domain
      validates_unique [:host, :domain_id] do |ds|
        ds.where(path: '', port: 0)
      end
    end

    def validate_uniqueness_on_host_domain_and_port
      validates_unique [:host, :domain_id, :port] do |ds|
        ds.where(path: '')
      end
    end

    def validate_uniqueness_on_host_domain_and_path
      validates_unique [:host, :domain_id, :path] do |ds|
        ds.where(port: 0)
      end
    end
  end
end
