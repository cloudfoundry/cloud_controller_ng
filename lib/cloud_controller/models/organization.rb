# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Organization < Sequel::Model
    class InvalidRelation < StandardError; end
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

    export_attributes :name
    import_attributes :name, :user_guids, :manager_guids, :billing_manager_guids, :auditor_guids, :domain_guids

    def before_create
      d = Domain.default_serving_domain
      add_domain_by_guid(d.guid) if d
      super
    end

    def validate
      validates_presence :name
      validates_unique   :name
    end

    def validate_domain(domain)
      return if domain && domain.owning_organization.nil?
      unless (domain &&
              domain.owning_organization_id &&
              domain.owning_organization_id == id)
        raise InvalidDomainRelation.new(domain.guid)
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
