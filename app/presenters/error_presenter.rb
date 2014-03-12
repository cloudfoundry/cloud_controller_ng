require 'presenters/error_hasher'

class ErrorPresenter
  def initialize(error, test_mode = false, error_hasher = ErrorHasher.new(error))
    @error        = error
    @error_hasher = error_hasher
    @test_mode    = test_mode
  end

  def client_error?
    response_code >= 400 && response_code <= 499
  end

  def log_message
    "Request failed: #{response_code}: #{@error_hasher.unsanitized_hash}"
  end

  def response_code
    @error.respond_to?(:response_code) ? @error.response_code : 500
  end

  def error_hash
    if @test_mode
      raise @error if !api_error? && errors_to_raise.include?(@error.class)
      @error_hasher.unsanitized_hash
    else
      @error_hasher.sanitized_hash
    end
  end

  def api_error?
    @error_hasher.api_error?
  end

  def errors_to_raise
    [WebMock::NetConnectNotAllowedError]
  end
end
