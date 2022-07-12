class MaxAppInstancesPolicy
  attr_reader :quota_definition

  def initialize(process, space_or_org, quota_definition, error_name)
    @process = process
    @space_or_org = space_or_org
    @quota_definition = quota_definition
    @error_name = error_name
    @errors = process.errors
  end

  def validate
    return unless @quota_definition
    return unless @process.started?
    return if @quota_definition.app_instance_limit == -1 || @process.stopped?

    other_apps = @space_or_org.processes.reject { |process| process.guid == @process.guid }

    proposed_instance_count = other_apps.reject { |process| process.state == 'STOPPED' }.sum(&:instances) + @process.instances

    if proposed_instance_count > @quota_definition.app_instance_limit
      @errors.add(:app_instance_limit, @error_name)
    end
  end
end
