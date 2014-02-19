require 'presenters/error_hasher'

class ErrorPresenter
  def initialize(error, error_hasher = ErrorHasher.new)
    @error = error
    @error_hasher = error_hasher
  end

  def api_error?
    @error.respond_to?(:error_code)
  end

  def client_error?
    response_code >= 400 && response_code <= 499
  end

  def log_message
    "Request failed: #{response_code}: #{unsanitized_hash}"
  end

  def unsanitized_hash
    @error_hasher.hashify(@error, api_error?)
  end

  def message
    @error.message
  end

  def response_code
    @error.respond_to?(:response_code) ? @error.response_code : 500
  end

  def sanitized_hash
    duplicate = unsanitized_hash.dup
    duplicate.delete("source")
    duplicate.delete("backtrace")
    duplicate
  end
end
