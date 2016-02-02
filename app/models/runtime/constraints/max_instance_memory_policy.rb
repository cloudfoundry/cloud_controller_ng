class MaxInstanceMemoryPolicy
  def initialize(app, policy_target, error_name)
    @app = app
    @policy_target = policy_target
    @error_name = error_name
    @errors = app.errors
  end

  def validate
    return unless policy_target
    return unless app.scaling_operation?
    if instance_memory_limit != VCAP::CloudController::QuotaDefinition::UNLIMITED && app_memory > instance_memory_limit
      @errors.add(:memory, error_name)
    end
  end

  private

  attr_reader :policy_target, :app, :error_name

  def app_memory
    app.memory || 0
  end

  def instance_memory_limit
    policy_target.instance_memory_limit
  end
end
