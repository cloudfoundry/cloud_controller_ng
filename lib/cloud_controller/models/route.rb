# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Route < Sequel::Model
    class InvalidDomainRelation < InvalidRelation; end

    many_to_one :domain
    many_to_one :organization

    many_to_many :apps, :before_add => :validate_app, :after_add => :run_after_add_app_hooks, :after_remove => :run_after_remove_app_hooks
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
      "#{host}.#{domain.name}"
    end

    def validate
      validates_presence :host
      validates_presence :domain
      validates_presence :organization

      if (organization && domain &&
          domain.owning_organization &&
          domain.owning_organization.id != organization.id)
        errors.add(:domain, :invalid_relation)
      end

      # TODO: not accurate regex
      validates_format   /^([\w\-]+)$/, :host
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

    # I'm refraining from full blown re-inventing Sequel instance hooks until
    # there is a compelling case for it
    def after_add_app_hook(&block)
      after_add_app_hooks.push(block)
    end

    def after_remove_app_hook(&block)
      after_remove_app_hooks.push(block)
    end

    private
    def run_after_add_app_hooks(app)
      after_add_app_hooks.each { |cb| cb.call(app) }
    end

    def run_after_remove_app_hooks(app)
      after_add_app_hooks.each { |cb| cb.call(app) }
    end

    def after_add_app_hooks
      @after_add_app_hooks ||= []
    end

    def after_remove_app_hooks
      @after_remove_app_hooks ||= []
    end
  end
end
