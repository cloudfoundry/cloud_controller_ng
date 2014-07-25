class MaxInstanceMemoryPolicy
  attr_reader :quota_definition

  def initialize(app, quota_definition, error_name)
    @app = app
    @quota_definition = quota_definition
    @error_name = error_name
    @errors = app.errors
  end

  def validate
    return unless @app.scaling_operation?

    if instance_memory_limit != -1 && app_memory > instance_memory_limit
      @errors.add(:memory, @error_name)
    end
  end

  private

  def app_memory
    @app.memory || 0
  end

  def instance_memory_limit
    return -1 unless @quota_definition
    quota_definition.instance_memory_limit
  end
end
