require_relative 'api_presenter'

class FeatureFlagPresenter < ApiPresenter
  def initialize(object, name, path)
    @object = object
    @name = name
    @path = path
  end

  def to_hash
    default_value = VCAP::CloudController::FeatureFlag::DEFAULT_FLAGS[@name.to_sym]
    {
      name: @name,
      enabled: @object.nil? ? default_value : @object.enabled,
      error_message: @object.nil? ? nil : @object.error_message,
      url: "#{@path}/#{@name}"
    }
  end
end
