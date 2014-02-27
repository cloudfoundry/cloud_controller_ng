class ErrorHasher < Struct.new(:error)
  UNKNOWN_ERROR_HASH = {
    "error_code" => "UnknownError",
    "description" => "An unknown error occurred.",
    "code" => 10001,
  }.freeze

  def unsanitized_hash
    return UNKNOWN_ERROR_HASH.dup if error.nil?

    payload = {
      "code" => 10001,
      "description" => error.message,
      "error_code" => "CF-#{error.class.name.demodulize}",
      "backtrace" => error.backtrace,
    }
    if api_error?
      payload["code"] = error.code
      payload["error_code"] = "CF-#{error.name}"
    end

    payload.merge!(error.to_h) if error.respond_to? :to_h
    payload
  end

  def sanitized_hash
    return UNKNOWN_ERROR_HASH unless api_error? or services_error?

    error_hash = unsanitized_hash

    sanitized_hash = {}
    allowed_keys.each do |key|
      sanitized_hash[key] = error_hash[key] if error_hash.has_key?(key)
    end

    sanitized_hash
  end

  def api_error?
    error.is_a?(VCAP::Errors::ApiError) || error.respond_to?(:error_code)
  end

  def services_error?
    error.respond_to?(:source)
  end

  private

  def allowed_keys
    ["error_code", "description", "code", "http"]
  end
end
