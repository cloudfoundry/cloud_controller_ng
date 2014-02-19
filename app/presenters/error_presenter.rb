require 'presenters/error_hasher'

class ErrorPresenter
  def initialize(error, error_hasher = ErrorHasher.new(error))
    @error = error
    @error_hasher = error_hasher
  end

  def client_error?
    response_code >= 400 && response_code <= 499
  end

  def log_message
    "Request failed: #{response_code}: #{unsanitized_hash}"
  end

  def response_code
    @error.respond_to?(:response_code) ? @error.response_code : 500
  end

  def unsanitized_hash
    @error_hasher.unsanitized_hash
  end

  def sanitized_hash
    @error_hasher.sanitized_hash
  end

  def api_error?
    @error_hasher.api_error?
  end
end
