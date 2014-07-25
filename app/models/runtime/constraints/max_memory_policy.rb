class MaxMemoryPolicy
  attr_reader :scope

  def initialize(app, quota_scope)
    @app = app
    @errors = app.errors
    @scope = quota_scope
  end

  def validate
    return unless @scope
    return unless @app.scaling_operation?

    unless @scope.has_remaining_memory(@app.additional_memory_requested)
      @errors.add(:memory, :quota_exceeded)
    end
  end
end
