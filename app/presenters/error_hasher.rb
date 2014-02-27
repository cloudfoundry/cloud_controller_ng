class ErrorHasher < Struct.new(:error)
  UNKNOWN_ERROR_HASH = {
    "error_code" => "UnknownError",
    "description" => "An unknown error occurred.",
    "code" => 10001,
  }.freeze

  def unsanitized_hash
    return UNKNOWN_ERROR_HASH if error.nil?

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
    error_hash = unsanitized_hash
    error_hash.delete("source")
    error_hash.delete("backtrace")
    unless api_error? || services_error?
      error_hash["error_code"] = "UnknownError"
      error_hash["description"] = "An unknown error occurred."
    end
    error_hash
  end

  def api_error?
    error.is_a?(VCAP::Errors::ApiError) || error.respond_to?(:error_code)
  end

  def services_error?
    error.respond_to?(:source)
  end
end
