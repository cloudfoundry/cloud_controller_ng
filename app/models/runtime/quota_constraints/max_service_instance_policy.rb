class MaxServiceInstancePolicy
  attr_reader :quota_definition

  def initialize(service_instance, existing_service_instance_count, quota_definition, error_name)
    @service_instance = service_instance
    @quota_definition = quota_definition
    @existing_service_instance_count = existing_service_instance_count
    @error_name = error_name
    @errors = service_instance.errors
  end

  def validate
    return unless @quota_definition
    @errors.add(:quota, @error_name) unless service_instance_quota_remaining?
  end

  private

  def service_instance_quota_remaining?
    @quota_definition.total_services == -1 || # unlimited
      desired_service_instance_count <= @quota_definition.total_services
  end

  def desired_service_instance_count
    @existing_service_instance_count + requested_service_instances
  end

  def requested_service_instances
    @service_instance.new? ? 1 : 0
  end

  def paid_services_allowed?
    @quota_definition.non_basic_services_allowed
  end
end
