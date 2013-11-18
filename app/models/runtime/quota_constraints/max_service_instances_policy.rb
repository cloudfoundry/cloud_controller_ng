class MaxServiceInstancePolicy
  def initialize(organization, service_instance)
    @organization = organization
    @service_instance = service_instance
    @quota_definition = organization.quota_definition
    @errors = service_instance.errors
  end

  def check_quota
    if paid_services_allowed?
      @errors.add(:org, :paid_quota_exceeded) unless service_instance_quota_remaining?
    elsif @service_instance.service_plan.free
      @errors.add(:org, :free_quota_exceeded) unless service_instance_quota_remaining?
    else
      @errors.add(:service_plan, :paid_services_not_allowed)
    end
  end

  private

  def service_instance_quota_remaining?
    @quota_definition.total_services == -1 || # unlimited
      @organization.service_instances.count < @quota_definition.total_services
  end

  def paid_services_allowed?
    @quota_definition.non_basic_services_allowed
  end
end
