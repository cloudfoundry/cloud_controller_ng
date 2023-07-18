require 'utils/uri_utils'
require 'models/helpers/process_types'
require 'cloud_controller/routing_api/disabled_routing_api_client'
require 'cloud_controller/route_validator'
require 'actions/services/route_binding_delete'

module VCAP::CloudController
  class Route < Sequel::Model
    class InvalidOrganizationRelation < CloudController::Errors::InvalidRelation; end

    class OutOfVIPException < CloudController::Errors::InvalidRelation; end

    many_to_one :domain
    many_to_one :space, after_set: :validate_changed_space
    one_through_one :organization, join_table: Space.table_name, left_key: :id, left_primary_key: :space_id, right_primary_key: :id, right_key: :organization_id

    one_to_many :route_mappings, class: 'VCAP::CloudController::RouteMappingModel', key: :route_guid, primary_key: :guid
    one_to_many :labels, class: 'VCAP::CloudController::RouteLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::RouteAnnotationModel', key: :resource_guid, primary_key: :guid

    # TODO: apps are actually processes
    many_to_many :apps, class: 'VCAP::CloudController::ProcessModel',
                        join_table:              RouteMappingModel.table_name,
                        left_primary_key:        :guid, left_key: :route_guid,
                        right_primary_key:       [:app_guid, :type], right_key: [:app_guid, :process_type],
                        distinct:                true,
                        order:                   Sequel.asc(:id),
                        conditions:              { type: ProcessTypes::WEB }

    many_to_many :shared_spaces,
          left_key:          :route_guid,
          left_primary_key:  :guid,
          right_key:         :target_space_guid,
          right_primary_key: :guid,
          join_table:        :route_shares,
          class: VCAP::CloudController::Space

    one_to_one :route_binding
    one_through_one :service_instance, join_table: :route_bindings

    add_association_dependencies route_mappings: :destroy

    export_attributes :host, :path, :domain_guid, :space_guid, :service_instance_guid, :port
    import_attributes :host, :path, :domain_guid, :space_guid, :app_guids, :port

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    def shared?
      return VCAP::CloudController::Space.where(routes_shared_from_other_spaces: self).empty? == false
    end

    def fqdn
      host.empty? ? domain.name : "#{host}.#{domain.name}"
    end

    def uri
      "#{fqdn}#{path}#{":#{port}" if !port.nil?}"
    end

    def as_summary_json
      {
        guid:   guid,
        host:   host,
        port:   port,
        path:   path,
        domain: {
          guid: domain.guid,
          name: domain.name
        }
      }
    end

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

      validates_format /\A([\w\-]+|\*)\z/, :host if host && !host.empty?

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
      errors.add(:name, :vip_offset) if vip_offset_exceeds_range?

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

      errors.add(:port, :invalid_port) if port < 0 || port > 65535
    end

    def validate_path
      return if path == ''

      if !UriUtils.is_uri?("pathcheck://#{host}#{path}")
        errors.add(:path, :invalid_path)
      end

      if path == '/'
        errors.add(:path, :single_slash)
      end

      if path[0] != '/'
        errors.add(:path, :missing_beginning_slash)
      end

      if path.match?(/\?/)
        errors.add(:path, :path_contains_question)
      end

      if path.length > 128
        errors.add(:path, :path_exceeds_valid_length)
      end
    end

    def domains_match?
      return false if domain.nil? || host.nil? || host.empty?

      !Domain.find(name: fqdn).nil?
    end

    def validate_changed_space(new_space)
      unless FeatureFlag.enabled? :route_sharing
        raise CloudController::Errors::InvalidAppRelation.new('Route and apps not in same space') if apps.any? { |app| app.space.id != space.id }
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

    def in_suspended_org?
      space.in_suspended_org?
    end

    def tcp?
      domain.shared? && domain.tcp? && port.present? && port > 0
    end

    def protocol
      self.domain.protocols.first
    end

    def internal?
      domain.internal
    end

    def vip
      vip_offset && internal_route_vip_range.nth(vip_offset).to_s
    end

    def wildcard_host?
      host == '*'
    end

    private

    def vip_offset_exceeds_range?
      return false if vip_offset.nil?
      return true if vip_offset <= 0

      vip_offset > internal_route_vip_range_len
    end

    def before_destroy
      destroy_route_bindings
      super
    end

    def find_next_vip_offset
      # This code courtesy of Jeremy Evans as part of discussion on
      # https://groups.google.com/d/msg/sequel-talk/3GJ8_mOgJ9U/roWJ2sWHAwAJ
      # See SQL self-joins for the reasoning behind this

      n = Route.exclude(vip_offset: 1).
          exclude { vip_offset - 1 =~ Route.select(:vip_offset) }.order(:vip_offset).get { vip_offset - 1 } ||
              (return (Route.max(:vip_offset) || 0) + 1)
      Route.where { vip_offset < n }.reverse(:vip_offset).get { vip_offset + 1 } || 1
    end

    def before_save
      if internal? && vip_offset.nil?
        len = internal_route_vip_range_len
        raise OutOfVIPException.new('out of vip_offset slots') if self.class.exclude(vip_offset: nil).count >= len

        self.vip_offset = find_next_vip_offset
      end
    end

    def internal_route_vip_range_len
      internal_route_vip_range.len - 2
    end

    def internal_route_vip_range
      @internal_route_vip_range ||= begin
        internal_route_vip_range = Config.config.get(:internal_route_vip_range)
        NetAddr::IPv4Net.parse(internal_route_vip_range)
      end
    end

    def destroy_route_bindings
      errors = RouteBindingDelete.new.delete(self.route_binding_dataset)
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
        ds.where(port: 0).exclude(space: space)
      end
    end

    def private_domain_cross_space_context_path_route_sharing_enabled?
      !Config.config.get(:disable_private_domain_cross_space_context_path_route_sharing)
    end

    def validate_host
      if host && host.length > Domain::MAXIMUM_DOMAIN_LABEL_LENGTH
        errors.add(:host, "must be no more than #{Domain::MAXIMUM_DOMAIN_LABEL_LENGTH} characters")
      end
    end

    def validate_fqdn
      return unless host

      length_with_period_separator = host.length + 1
      host_label_length = host.empty? ? 0 : length_with_period_separator
      total_domain_too_long = host_label_length + domain.name.length > Domain::MAXIMUM_FQDN_DOMAIN_LENGTH
      errors.add(:host, "combined with domain name must be no more than #{Domain::MAXIMUM_FQDN_DOMAIN_LENGTH} characters") if total_domain_too_long
    end

    def validate_domain
      errors.add(:domain, :invalid_relation) if !valid_domain
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

      if space.space_quota_definition && !space_routes_policy.allow_more_routes?(1)
        errors.add(:space, :total_routes_exceeded)
      end

      if !org_routes_policy.allow_more_routes?(1)
        errors.add(:organization, :total_routes_exceeded)
      end
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
        if !space_reserved_route_ports_policy.allow_more_route_ports?
          errors.add(:space, :total_reserved_route_ports_exceeded)
        end
      end

      if !org_reserved_route_ports_policy.allow_more_route_ports?
        errors.add(:organization, :total_reserved_route_ports_exceeded)
      end
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
