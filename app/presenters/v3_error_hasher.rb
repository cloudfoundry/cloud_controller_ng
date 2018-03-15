require 'presenters/base_error_hasher'

class V3ErrorHasher < BaseErrorHasher
  UNKNOWN_ERROR_HASH = {
    'title'  => 'UnknownError',
    'detail' => 'An unknown error occurred.',
    'code'   => 10001,
  }.freeze

  def unsanitized_hash
    return { 'errors' => [UNKNOWN_ERROR_HASH.dup] } if error.nil?

    errors_payload = if compound_error?
                       compound_error_payload
                     elsif api_error?
                       api_error_payload
                     elsif services_error?
                       services_error_payload
                     else
                       unknown_error_payload
                     end

    { 'errors' => errors_payload }
  end

  def sanitized_hash
    return_hash = unsanitized_hash
    return_hash['errors'] = unsanitized_hash['errors'].map do |error|
      error.keep_if { |k, _| allowed_keys.include? k }
    end
    return_hash
  end

  private

  def compound_error_payload
    hash_api_errors(error.underlying_errors)
  end

  def api_error_payload
    hash_api_errors([error])
  end

  def services_error_payload
    [
      with_test_mode_info(hash: services_error_hash, an_error: error, backtrace: error.backtrace)
    ]
  end

  def unknown_error_payload
    [
      with_test_mode_info(hash: UNKNOWN_ERROR_HASH.dup, an_error: error, backtrace: error.backtrace)
    ]
  end

  def hash_api_errors(api_errors)
    api_errors.map do |an_error|
      with_test_mode_info(hash: api_error_hash(an_error), an_error: an_error, backtrace: error.backtrace)
    end
  end

  def api_error_hash(an_error)
    {
      'detail' => an_error.message,
      'title'  => "CF-#{an_error.name}",
      'code'   => an_error.code,
    }
  end

  def services_error_hash
    error_hash = error.to_h
    {
      'detail' => error_hash['detail'] || error.message,
      'title' => error_hash['title'] || "CF-#{error.class.name.demodulize}",
      'code' => error_hash['code'] || UNKNOWN_ERROR_HASH['code'],
    }
  end

  def with_test_mode_info(hash:, an_error:, backtrace:)
    hash['test_mode_info'] = test_mode_hash(an_error: an_error, backtrace: backtrace)
    hash
  end

  def test_mode_hash(an_error:, backtrace:)
    info = {
      'detail'    => an_error.message,
      'title'     => generate_debug_title(an_error),
      'backtrace' => backtrace,
    }
    info.merge!(an_error.to_h) if an_error.respond_to?(:to_h)

    info
  end

  def generate_debug_title(error)
    if error.respond_to?(:name)
      "CF-#{error.name}"
    else
      "CF-#{error.class.name.demodulize}"
    end
  end

  def allowed_keys
    ['title', 'detail', 'code']
  end
end
