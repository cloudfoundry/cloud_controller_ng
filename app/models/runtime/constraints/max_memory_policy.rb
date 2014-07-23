class MaxMemoryPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    organization = @app.organization
    return unless organization

    return unless @app.scaling_operation?
    instance_memory_limit = organization.quota_definition.instance_memory_limit
    if instance_memory_limit != -1 && @app.memory > instance_memory_limit
      @errors.add(:memory, :instance_memory_limit_exceeded)
    end

    if organization.memory_remaining < @app.additional_memory_requested
      @errors.add(:memory, :quota_exceeded)
    end
  end
end
