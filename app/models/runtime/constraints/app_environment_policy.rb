class AppEnvironmentPolicy
  RESERVED_ENV_VAR_ERROR_MSG = "reserved_key:%s"

  def initialize(app)
    @errors = app.errors
    @environment_json = app.environment_json
  end

  def validate
    return if @environment_json.nil?
    unless @environment_json.kind_of?(Hash)
      @errors.add(:environment_json, :invalid_environment)
      return
    end
    @environment_json.keys.each do |k|
      @errors.add(:environment_json, RESERVED_ENV_VAR_ERROR_MSG % k) if k =~ /^(vcap|vmc)_/i
    end
  rescue Yajl::ParseError
    @errors.add(:environment_json, :invalid_json)
  end
end
