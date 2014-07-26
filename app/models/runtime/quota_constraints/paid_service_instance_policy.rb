class PaidServiceInstancePolicy
  attr_reader :quota_definition

  def initialize(service_instance, quota_definition, error_name)
    @service_instance = service_instance
    @quota_definition = quota_definition
    @error_name = error_name
    @errors = service_instance.errors
  end

  def validate
    return unless @quota_definition
    unless paid_services_allowed? || @service_instance.service_plan.free
      @errors.add(:service_plan, @error_name)
    end
  end

  private

  def paid_services_allowed?
    @quota_definition.non_basic_services_allowed
  end
end
