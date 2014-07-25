class MaxInstanceMemoryPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    return unless @app.organization
    return unless @app.scaling_operation?

    if instance_memory_limit != -1 && app_memory > instance_memory_limit
      @errors.add(:memory, :instance_memory_limit_exceeded)
    end
  end

  private

  def app_memory
    @app.memory || 0
  end

  def instance_memory_limit
    @app.organization.quota_definition.instance_memory_limit || -1
  end
end
