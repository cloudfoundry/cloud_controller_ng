class ErrorHasher < Struct.new(:error)
  def unsanitized_hash
    return nil_hash if error.nil?

    payload = {
      "code" => 10001,
      "description" => error.message,
      "error_code" => "CF-#{Hashify.demodulize(error.class)}",
    }
    payload["code"] = error.error_code if api_error?

    payload.merge!(error_hash(error))
    payload

  end

  def sanitized_hash
    error_hash = unsanitized_hash
    error_hash.delete("source")
    error_hash.delete("backtrace")
    unless api_error? || services_error?
      error_hash["error_code"] = "UnknownError"
      error_hash["description"] = "An unknown error occurred."
      error_hash.delete("types")
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

  def nil_hash
    {
      "error_code" => "UnknownError",
      "description" => "An unknown error occurred.",
      "code" => 10001,
    }
  end

  def error_hash(error)
    if error.respond_to?(:to_h)
      error.to_h
    else
      Hashify.exception(error)
    end
  end
end
