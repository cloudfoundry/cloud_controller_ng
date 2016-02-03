class BaseMaxInstanceMemoryPolicy
  def initialize(resource, policy_target, error_name)
    @resource = resource
    @policy_target = policy_target
    @error_name = error_name
  end

  def validate
    return unless policy_target
    return unless additional_checks
    if instance_memory_limit != VCAP::CloudController::QuotaDefinition::UNLIMITED && resource_memory > instance_memory_limit
      resource.errors.add(field, error_name)
    end
  end

  private

  attr_reader :policy_target, :resource, :error_name

  def resource_memory
    resource.public_send field || 0
  end

  def instance_memory_limit
    policy_target.instance_memory_limit
  end

  def additional_checks
    true
  end

  def field
    :memory
  end
end

class AppMaxInstanceMemoryPolicy < BaseMaxInstanceMemoryPolicy
  private

  def additional_checks
    resource.scaling_operation?
  end
end

class TaskMaxInstanceMemoryPolicy < BaseMaxInstanceMemoryPolicy
  private

  def field
    :memory_in_mb
  end
end
