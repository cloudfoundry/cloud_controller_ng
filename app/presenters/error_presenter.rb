require 'presenters/v2_error_hasher'

class ErrorPresenter
  def initialize(error, test_mode=false, error_hasher=V2ErrorHasher.new(error))
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

  def to_hash
    raise @error if raise_500? && response_code == 500

    if test_mode
      @error_hasher.unsanitized_hash
    else
      @error_hasher.sanitized_hash
    end
  end

  def api_error?
    @error_hasher.api_error?
  end

  private

  def raise_500?
    # `test_mode` can also be set by ENV['CC_TEST'] in some cases
    test_mode && Rails.env.test?
  end

  attr_reader :test_mode
end
