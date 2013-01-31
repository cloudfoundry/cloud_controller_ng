# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/dea/dea_client"

module VCAP::CloudController::Models
  class Route < Sequel::Model
    class InvalidDomainRelation < InvalidRelation; end
    class InvalidAppRelation < InvalidRelation; end

    many_to_one :domain
    many_to_one :space

    many_to_many :apps,
                 :before_add => :validate_app,
                 :after_add => :mark_app_routes_changed,
                 :after_remove => :mark_app_routes_changed
    add_association_dependencies :apps => :nullify

    export_attributes :host, :domain_guid, :space_guid
    import_attributes :host, :domain_guid, :space_guid, :app_guids

    def fqdn
      !host.empty? ? "#{host}.#{domain.name}" : domain.name
    end

    def as_summary_json
      {
        :guid => guid,
        :host => host,
        :domain => {
          :guid => domain.guid,
          :name => domain.name
        }
      }
    end

    def organization
      space.organization if space
    end

    def validate
      validates_presence :domain
      validates_presence :space

      errors.add(:host, :presence) if host.nil?

      validates_format   /^([\w\-]+)$/, :host if (host && !host.empty?)
      validates_unique   [:host, :domain_id]

      if domain
        unless domain.wildcard
          errors.add(:host, :host_not_empty) unless (host.nil? || host.empty?)
        end

        if space && space.domains_dataset.filter(:id => domain.id).count < 1
          errors.add(:domain, :invalid_relation)
        end
      end
    end

    def validate_app(app)
      return unless (space && app && domain)

      unless app.space == space
        raise InvalidAppRelation.new(app.guid)
      end

      unless space.domains.include?(domain)
        raise InvalidDomainRelation.new(domain.guid)
      end
    end

    def self.user_visibility_filter(user)
      orgs = Organization.filter({
        :managers => [user],
        :auditors => [user],
      }.sql_or)

      spaces = Space.filter({
        :developers => [user],
        :auditors => [user],
        :managers => [user],
        :organization => orgs,
      }.sql_or)

      user_visibility_filter_with_admin_override(:space => spaces)
    end

    private

    def around_destroy
      loaded_apps = apps
      super

      loaded_apps.each do |app|
        mark_app_routes_changed(app)
      end
    end

    def mark_app_routes_changed(app)
      app.routes_changed = true
      if app.dea_update_pending?
        VCAP::CloudController::DeaClient.update_uris(app)
      end
    end
  end
end
