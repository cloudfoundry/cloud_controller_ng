# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Space < Sequel::Model
    class InvalidDeveloperRelation < InvalidRelation; end
    class InvalidAuditorRelation   < InvalidRelation; end
    class InvalidManagerRelation   < InvalidRelation; end
    class InvalidDomainRelation    < InvalidRelation; end

    define_user_group :developers, :reciprocal => :spaces,
                      :before_add => :validate_developer

    define_user_group :managers, :reciprocal => :managed_spaces,
                      :before_add => :validate_manager

    define_user_group :auditors, :reciprocal => :audited_spaces,
                      :before_add => :validate_auditor

    many_to_one       :organization
    one_to_many       :apps
    one_to_many       :service_instances
    one_to_many       :routes
    # TODO: one_to_many       :crash_events, :dataset => lambda { VCAP::CloudController::Models::CrashEvent.filter(:app => apps) }
    one_to_many       :default_users, :class => "VCAP::CloudController::Models::User", :key => :default_space_id
    many_to_many      :domains, :before_add => :validate_domain

    add_association_dependencies :domains => :nullify, :default_users => :nullify,
      :apps => :destroy, :service_instances => :destroy, :routes => :destroy

    default_order_by  :name

    export_attributes :name, :organization_guid

    import_attributes :name, :organization_guid, :developer_guids,
                      :manager_guids, :auditor_guids, :domain_guids

    strip_attributes  :name

    def in_organization?(user)
      organization && organization.users.include?(user)
    end

    def before_create
      add_inheritable_domains
      super
    end

    def validate
      validates_presence :name
      validates_presence :organization
      validates_unique   [:organization_id, :name]
    end

    def validate_developer(user)
      # TODO: unlike most other validations, is *NOT* being enforced by DB
      raise InvalidDeveloperRelation.new(user.guid) unless in_organization?(user)
    end

    def validate_manager(user)
      raise InvalidManagerRelation.new(user.guid) unless in_organization?(user)
    end

    def validate_auditor(user)
      raise InvalidAuditorRelation.new(user.guid) unless in_organization?(user)
    end

    def validate_domain(domain)
      return if domain && domain.owning_organization.nil? || organization.nil?

      unless domain.owning_organization_id == organization.id
        raise InvalidDomainRelation.new(domain.guid)
      end
    end

    def add_inheritable_domains
      return unless organization

      organization.domains.each do |d|
        add_domain_by_guid(d.guid) unless d.owning_organization
      end
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :organization => user.organizations_dataset
      )
    end
  end
end
