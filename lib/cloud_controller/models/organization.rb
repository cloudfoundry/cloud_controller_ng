# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Organization < Sequel::Model
    class InvalidDomainRelation < InvalidRelation; end

    one_to_many       :spaces
    one_to_many       :service_instances, :dataset => lambda { VCAP::CloudController::Models::ServiceInstance.
                                                          filter(:space => spaces) }
    many_to_many      :domains, :before_add => :validate_domain
    add_association_dependencies :domains => :nullify

    many_to_one       :service_instances_quota_definition
    many_to_one       :memory_quota_definition

    define_user_group :users
    define_user_group :managers, :reciprocal => :managed_organizations
    define_user_group :billing_managers,
                      :reciprocal => :billing_managed_organizations
    define_user_group :auditors,
                      :reciprocal => :audited_organizations

    strip_attributes  :name

    default_order_by  :name

    export_attributes :name, :billing_enabled,
                      :service_instances_quota_definition_guid,
                      :memory_quota_definition_guid
    import_attributes :name, :billing_enabled,
                      :user_guids, :manager_guids, :billing_manager_guids,
                      :auditor_guids, :domain_guids,
                      :service_instances_quota_definition_guid,
                      :memory_quota_definition_guid

    alias :billing_enabled? :billing_enabled

    def before_create
      add_inheritable_domains
      add_default_quota
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

      if column_changed?(:service_instances_quota_definition_id) && !new?
        unless VCAP::CloudController::SecurityContext.current_user_is_admin?
          errors.add(:service_instances_quota_definition, :not_authorized)
        end
      end

      if column_changed?(:memory_quota_definition_id) && !new?
        unless VCAP::CloudController::SecurityContext.current_user_is_admin?
          errors.add(:memory_quota_definition, :not_authorized)
        end
      end
    end

    def before_save
      super
      if column_changed?(:billing_enabled) && billing_enabled?
        OrganizationStartEvent.create_from_org(self)
        # retroactively emit start events for services
        spaces.map(&:service_instances).flatten.each do |si|
          ServiceCreateEvent.create_from_service_instance(si)
        end
        spaces.map(&:apps).flatten.each do |app|
          AppStartEvent.create_from_app(app) if app.started?
        end
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

    def add_default_quota
      unless service_instances_quota_definition_id
        self.service_instances_quota_definition_id =
          ServiceInstancesQuotaDefinition.default.id
      end

      unless memory_quota_definition_id
        self.memory_quota_definition_id =
          MemoryQuotaDefinition.default.id
      end
    end

    def service_instance_quota_remaining?
      cap = service_instances_quota_definition.total_services
      service_instances.count < cap
    end

    def paid_services_allowed?
      service_instances_quota_definition.non_basic_services_allowed
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
