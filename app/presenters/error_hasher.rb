class ErrorHasher
  def hashify(error, api_error)
    payload = {
      "code" => 10001,
      "description" => error.message,
      "error_code" => "CF-#{Hashify.demodulize(error.class)}",
    }
    payload["code"] = error.error_code if api_error

    payload.merge!(error_hash(error))
    payload
  end

  private

  def error_hash(error)
    if error.respond_to?(:to_h)
      error.to_h
    else
      Hashify.exception(error)
    end
  end
end
