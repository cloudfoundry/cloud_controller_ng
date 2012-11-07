# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Organization < Sequel::Model
    class InvalidDomainRelation < InvalidRelation; end

    one_to_many       :spaces

    many_to_many      :domains, :before_add => :validate_domain
    add_association_dependencies :domains => :nullify

    define_user_group :users
    define_user_group :managers, :reciprocal => :managed_organizations
    define_user_group :billing_managers,
                      :reciprocal => :billing_managed_organizations
    define_user_group :auditors,
                      :reciprocal => :audited_organizations

    strip_attributes  :name

    default_order_by  :name

    export_attributes :name, :billing_enabled
    import_attributes :name, :billing_enabled,
                      :user_guids, :manager_guids, :billing_manager_guids,
                      :auditor_guids, :domain_guids

    alias :billing_enabled? :billing_enabled

    def before_create
      add_inheritable_domains
      super
    end

    def validate
      validates_presence :name
      validates_unique   :name

      if column_changed?(:billing_enabled)
        unless VCAP::CloudController::SecurityContext.current_user_is_admin?
          errors.add(:billing_enabled, :not_authorized)
        end

        orig_val, new_val = column_change(:billing_enabled)
        if orig_val == true && new_val == false
          errors.add(:billing_enabled, :not_allowed)
        end
      end
    end

    def before_save
      super
      if column_changed?(:billing_enabled) && billing_enabled?
        OrganizationStartEvent.create_from_org(self)
      end
    end

    def validate_domain(domain)
      return if domain && domain.owning_organization.nil?
      unless (domain &&
              domain.owning_organization_id &&
              domain.owning_organization_id == id)
        raise InvalidDomainRelation.new(domain.guid)
      end
    end

    def add_inheritable_domains
      Domain.shared_domains.each do |d|
        add_domain_by_guid(d.guid)
      end
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override({
        :managers => [user],
        :users => [user],
        :billing_managers => [user],
        :auditors => [user] }.sql_or)
    end
  end
end
