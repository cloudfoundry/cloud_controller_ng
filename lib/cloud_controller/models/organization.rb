# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Organization < Sequel::Model
    class InvalidDomainRelation < InvalidRelation; end

    one_to_many       :spaces
    one_to_many       :service_instances, :dataset => lambda { VCAP::CloudController::Models::ServiceInstance.filter(:space => spaces) }
    one_to_many       :apps, :dataset => lambda { App.filter(:space => spaces) }
    one_to_many       :app_events, :dataset => lambda { VCAP::CloudController::Models::AppEvent.filter(:app => apps) }
    one_to_many       :owned_domain, :class => "VCAP::CloudController::Models::Domain", :key => :owning_organization_id
    many_to_many      :domains, :before_add => :validate_domain
    many_to_one       :quota_definition

    add_association_dependencies :domains => :nullify,
      :spaces => :destroy, :service_instances => :destroy, :owned_domain => :destroy

    define_user_group :users
    define_user_group :managers, :reciprocal => :managed_organizations
    define_user_group :billing_managers,
                      :reciprocal => :billing_managed_organizations
    define_user_group :auditors,
                      :reciprocal => :audited_organizations

    strip_attributes  :name

    default_order_by  :name

    export_attributes :name, :billing_enabled, :quota_definition_guid, :status
    import_attributes :name, :billing_enabled,
                      :user_guids, :manager_guids, :billing_manager_guids,
                      :auditor_guids, :domain_guids, :quota_definition_guid,
                      :status

    def billing_enabled?
      billing_enabled
    end

    def before_create
      add_inheritable_domains
      add_default_quota
      super
    end

    def validate
      validates_presence :name
      validates_unique   :name
      validate_only_admin_can_update(:billing_enabled)
      validate_only_admin_can_update(:quota_definition_id)
    end

    def validate_only_admin_can_enable_on_new(field_name)
      if new? && !!public_send(field_name)
        require_admin_for(field_name)
      end
    end

    def validate_only_admin_can_update(field_name)
      if !new? && column_changed?(field_name)
        require_admin_for(field_name)
      end
    end

    def require_admin_for(field_name)
      unless VCAP::CloudController::SecurityContext.current_user_is_admin?
        errors.add(field_name, :not_authorized)
      end
    end

    def before_save
      super
      if column_changed?(:billing_enabled) && billing_enabled?
         @is_billing_enabled = true
      end
    end

    def after_save
      super
      # We cannot start billing events without the guid being assigned to the org.
      if @is_billing_enabled
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
      unless quota_definition_id
        self.quota_definition_id = QuotaDefinition.default.id
      end
    end

    def service_instance_quota_remaining?
      quota_definition.total_services == -1 || # unlimited
        service_instances.count < quota_definition.total_services
    end

    def check_quota?(service_plan)
      return check_quota_for_trial_db if service_plan.trial_db?
      check_quota_without_trial_db(service_plan)
    end

    def check_quota_for_trial_db
      if trial_db_allowed?
        return {:type => :org, :name => :trial_quota_exceeded} if trial_db_allocated?
      elsif paid_services_allowed?
        return {:type => :org, :name => :paid_quota_exceeded} unless service_instance_quota_remaining?
      else
        return {:type => :service_plan, :name => :paid_services_not_allowed }
      end

      {}
    end

    def check_quota_without_trial_db(service_plan)
      if paid_services_allowed?
        return {:type => :org, :name => :paid_quota_exceeded } unless service_instance_quota_remaining?
      elsif service_plan.free
        return {:type => :org, :name => :free_quota_exceeded } unless service_instance_quota_remaining?
      else
        return {:type => :service_plan, :name => :paid_services_not_allowed }
      end

      {}
    end

    def paid_services_allowed?
      quota_definition.non_basic_services_allowed
    end

    def trial_db_allowed?
      quota_definition.trial_db_allowed
    end

    # Does any service instance in any space have a trial DB plan?
    def trial_db_allocated?
      service_instances.each do |svc_instance|
        return true if svc_instance.service_plan.trial_db?
      end

      false
    end

    def memory_remaining
      memory_used = apps_dataset.sum(Sequel.*(:memory, :instances)) || 0
      quota_definition.memory_limit - memory_used
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(Sequel.or({
        :managers => [user],
        :users => [user],
        :billing_managers => [user],
        :auditors => [user] }))
    end
  end
end
