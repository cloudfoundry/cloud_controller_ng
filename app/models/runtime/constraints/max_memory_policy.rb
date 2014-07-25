class MaxMemoryPolicy
  attr_reader :policy_target
  
  def initialize(app, policy_target, error_name)
    @app = app
    @errors = app.errors
    @policy_target = policy_target
    @error_name = error_name
  end

  def validate
    return unless @policy_target
    return unless @app.scaling_operation?

    unless @policy_target.has_remaining_memory(@app.additional_memory_requested)
      @errors.add(:memory, @error_name)
    end
  end
end
