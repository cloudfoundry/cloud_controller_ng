require 'cloud_controller/dea/client'

module VCAP::CloudController
  class Route < Sequel::Model
    ROUTE_REGEX = /\A#{URI.regexp}\Z/.freeze

    class InvalidDomainRelation < VCAP::Errors::InvalidRelation; end
    class InvalidAppRelation < VCAP::Errors::InvalidRelation; end
    class InvalidOrganizationRelation < VCAP::Errors::InvalidRelation; end
    class DockerDisabled < VCAP::Errors::InvalidRelation; end

    many_to_one :domain
    many_to_one :space, after_set: :validate_changed_space
    many_to_one :service_instance

    many_to_many :app_models, join_table: :apps_v3_routes

    many_to_many :apps,
      before_add:   :validate_app,
      after_add:    :handle_add_app,
      after_remove: :handle_remove_app

    add_association_dependencies apps: :nullify

    export_attributes :host, :path, :domain_guid, :space_guid, :service_instance_guid
    import_attributes :host, :path, :domain_guid, :space_guid, :app_guids

    def fqdn
      host.empty? ? domain.name : "#{host}.#{domain.name}"
    end

    def uri
      "#{fqdn}#{path}"
    end

    def as_summary_json
      {
        guid:   guid,
        host:   host,
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

    def organization
      space.organization if space
    end

    def validate
      validates_presence :domain
      validates_presence :space

      errors.add(:host, :presence) if host.nil?

      validates_format /^([\w\-]+|\*)$/, :host if host && !host.empty?

      if path.empty?
        validates_unique [:host, :domain_id]  do |ds|
          ds.where(path: '')
        end
      else
        validates_unique [:host, :domain_id, :path]
      end

      validate_path

      validate_domain
      validate_total_routes
      errors.add(:host, :domain_conflict) if domains_match?

      validate_service_instance
    end

    def validate_path
      return if path == ''

      if !ROUTE_REGEX.match("pathcheck://#{host}#{path}")
        errors.add(:path, :invalid_path)
      end

      if path == '/'
        errors.add(:path, :single_slash)
      end

      if path[0] != '/'
        errors.add(:path, :missing_beginning_slash)
      end

      if path =~ /\?/
        errors.add(:path, :path_contains_question)
      end
    end

    def domains_match?
      return false if domain.nil? || host.nil? || host.empty?
      !Domain.find(name: fqdn).nil?
    end

    def validate_app(app)
      return unless space && app && domain

      unless app.space == space
        raise InvalidAppRelation.new(app.guid)
      end

      unless domain.usable_by_organization?(space.organization)
        raise InvalidDomainRelation.new(domain.guid)
      end
    end

    def validate_changed_space(new_space)
      apps.each { |app| validate_app(app) }
      raise InvalidOrganizationRelation if domain && !domain.usable_by_organization?(new_space.organization)
    end

    def self.user_visibility_filter(user)
      {
        space_id: Space.dataset.join_table(:inner, :spaces_developers, space_id: :id, user_id: user.id).select(:spaces__id).union(
            Space.dataset.join_table(:inner, :spaces_managers, space_id: :id, user_id: user.id).select(:spaces__id)
          ).union(
            Space.dataset.join_table(:inner, :spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__id)
          ).union(
            Space.dataset.join_table(:inner, :organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__id)
          ).union(
            Space.dataset.join_table(:inner, :organizations_auditors, organization_id: :organization_id, user_id: user.id).select(:spaces__id)
          ).select(:id)
      }
    end

    def in_suspended_org?
      space.in_suspended_org?
    end

    private

    def around_destroy
      loaded_apps = apps
      super

      loaded_apps.each do |app|
        handle_remove_app(app)

        if app.dea_update_pending?
          Dea::Client.update_uris(app)
        end
      end
    end

    def handle_add_app(app)
      app.handle_add_route(self)
    end

    def handle_remove_app(app)
      app.handle_remove_route(self)
    end

    def validate_domain
      errors.add(:domain, :invalid_relation) if !valid_domain
    end

    def valid_domain
      return false if domain.nil?

      domain_change = column_change(:domain_id)
      return false if !new? && domain_change && domain_change[0] != domain_change[1]

      if (domain.shared? && !host.present?) ||
          (space && !domain.usable_by_organization?(space.organization))
        return false
      end

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

    def validate_service_instance
      return unless service_instance

      unless service_instance.service.requires.include? 'route_forwarding'
        errors.add(:service_instance, :route_binding_not_allowed)
      end

      unless service_instance.space == self.space
        errors.add(:service_instance, :space_mismatch)
      end
    end
  end
end
