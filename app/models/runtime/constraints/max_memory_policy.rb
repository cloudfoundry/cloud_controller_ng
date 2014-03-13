class MaxMemoryPolicy
  def initialize(app, organization)
    @app = app
    @errors = app.errors
    @organization = organization
  end

  def validate
    if @organization.memory_remaining < @app.additional_memory_requested
      @errors.add(:memory, :quota_exceeded)
    end
  end
end
