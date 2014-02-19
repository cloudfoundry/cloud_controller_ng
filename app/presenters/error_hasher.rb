class ErrorHasher < Struct.new(:error)
  def unsanitized_hash
    constructed_hash
  end

  def sanitized_hash
    error_hash = constructed_hash
    error_hash.delete("source")
    error_hash.delete("backtrace")
    unless api_error? || services_error?
      error_hash["error_code"] = "UnknownError"
      error_hash["description"] = "An unknown error occured."
    end
    error_hash
  end

  def api_error?
    error.respond_to?(:error_code)
  end

  def services_error?
    error.respond_to?(:source)
  end

  private

  def constructed_hash
    payload = {
      "code" => 10001,
      "description" => error.message,
      "error_code" => "CF-#{Hashify.demodulize(error.class)}",
    }
    payload["code"] = error.error_code if api_error?

    payload.merge!(error_hash(error))
    payload
  end

  def error_hash(error)
    if error.respond_to?(:to_h)
      error.to_h
    else
      Hashify.exception(error)
    end
  end
end
