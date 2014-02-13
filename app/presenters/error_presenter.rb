class ErrorPresenter
  def initialize(error)
    @error = error
  end

  def blow_up?
    !@error.respond_to?(:error_code)
  end

  def client_error?
    response_code >= 400 && response_code <= 499
  end

  def log_message
    "Request failed: #{response_code}: #{payload}"
  end

  def payload
    payload = {
      'code' => 10001,
      'description' => @error.message,
      'error_code' => "CF-#{Hashify.demodulize(@error.class)}"
    }

    if @error.respond_to?(:error_code)
      payload['code'] = @error.error_code
    end

    if @error.respond_to?(:to_h)
      payload.merge!(@error.to_h)
    else
      payload.merge!(Hashify.exception(@error))
    end

    payload
  end

  def response_code
    @error.respond_to?(:response_code) ? @error.response_code : 500
  end
end
