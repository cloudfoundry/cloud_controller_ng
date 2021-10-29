class MaxServiceKeysPolicy
  attr_reader :quota_definition

  def initialize(service_key, existing_service_keys_dataset, quota_definition, error_name)
    @service_key = service_key
    @existing_service_keys_dataset = existing_service_keys_dataset
    @quota_definition = quota_definition
    @error_name = error_name
    @errors = service_key.errors
  end

  def validate
    return unless @quota_definition

    @errors.add(:quota, @error_name) unless service_keys_quota_remaining?
  end

  private

  def service_keys_quota_remaining?
    @quota_definition.total_service_keys == -1 || # unlimited
      @existing_service_keys_dataset.count + requested_service_key <= @quota_definition.total_service_keys
  end

  def requested_service_key
    @service_key.new? ? 1 : 0
  end
end
