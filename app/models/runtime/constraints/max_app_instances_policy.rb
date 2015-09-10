class MaxAppInstancesPolicy
  def initialize(app, organization, quota_definition, error_name)
    @app = app
    @organization = organization
    @quota_definition = quota_definition
    @error_name = error_name
    @errors = app.errors
  end

  def validate
    return unless @quota_definition
    return unless @app.scaling_operation?
    return if @quota_definition.app_instance_limit == -1

    other_apps = @organization.apps.reject { |app| app.guid == @app.guid }

    proposed_instance_count = other_apps.sum(&:instances) + @app.instances

    if proposed_instance_count > @quota_definition.app_instance_limit
      @errors.add(:app_instance_limit, @error_name)
    end
  end
end
