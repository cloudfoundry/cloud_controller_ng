# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/dea/dea_client"

module VCAP::CloudController::Models
  class Route < Sequel::Model
    class InvalidDomainRelation < InvalidRelation; end

    many_to_one :domain
    many_to_one :organization

    many_to_many :apps, :before_add => :validate_app, :after_add => :mark_app_routes_changed, :after_remove => :mark_app_routes_changed
    add_association_dependencies :apps => :nullify

    export_attributes :host, :domain_guid, :organization_guid
    import_attributes :host, :domain_guid, :organization_guid, :app_guids
    strip_attributes  :host

    def spaces
      organization.spaces
    end

    def spaces_dataset
      organization.spaces_dataset
    end

    def fqdn
      host ? "#{host}.#{domain.name}" : domain.name
    end

    def validate
      if domain && !domain.wildcard
        errors.add(:host, :host_not_nil) unless host.nil?
      end

      validates_presence :domain
      validates_presence :organization

      if (organization && domain &&
          domain.owning_organization &&
          domain.owning_organization.id != organization.id)
        errors.add(:domain, :invalid_relation)
      end

      # TODO: not accurate regex
      validates_format   /^([\w\-]+)$/, :host if host
      validates_unique   [:host, :domain_id]
    end

    def validate_app(app)
      return unless (organization && app)
      unless app.space.domains.include?(domain)
        raise InvalidDomainRelation.new(domain.guid)
      end
    end

    def self.user_visibility_filter(user)
      spaces = Space.filter({
        :developers => [user],
        :auditors => [user],
        :managers => [user]
      }.sql_or)

      orgs = Organization.filter({
        :managers => [user],
        :auditors => [user],
        :spaces => spaces
      }.sql_or)

      user_visibility_filter_with_admin_override(:organization => orgs)
    end

    private
    def mark_app_routes_changed(app)
      app.routes_changed = true
      # I hate putting this in the model, but let's get this feature shippped
      # TODO: use event emitter to decouple this from the model
      if app.dea_update_pending?
        VCAP::CloudController::DeaClient.update_uris(app)
      end
    end

  end
end
