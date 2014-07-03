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
      desired_service_instance_count <= @quota_definition.total_services
  end

  def desired_service_instance_count
    existing_service_instances + requested_service_instances
  end

  def existing_service_instances
    managed_service_instances = @organization.service_instances.select{|si| si.is_gateway_service }
    managed_service_instances.count
  end

  def requested_service_instances
    @service_instance.new? ? 1 : 0
  end

  def paid_services_allowed?
    @quota_definition.non_basic_services_allowed
  end
end
