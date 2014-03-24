class MaxMemoryPolicy
  def initialize(app)
    @app = app
    @errors = app.errors
  end

  def validate
    organization = @app.organization
    return unless organization

    return unless @app.scaling_operation?
    if organization.memory_remaining < @app.additional_memory_requested
      @errors.add(:memory, :quota_exceeded)
    end
  end
end
