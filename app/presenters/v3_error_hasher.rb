require 'presenters/base_error_hasher'

class V3ErrorHasher < BaseErrorHasher
  UNKNOWN_ERROR_HASH = {
    'title'  => 'UnknownError',
    'detail' => 'An unknown error occurred.',
    'code'   => 10001,
  }.freeze

  def unsanitized_hash
    return { 'errors' => [UNKNOWN_ERROR_HASH.dup] } if error.nil?

    payload = if compound_error?
                compound_error_hash
              elsif api_error?
                [with_test_mode_info(api_error_hash(error))]
              elsif services_error?
                [with_test_mode_info(services_error_hash)]
              else
                [with_test_mode_info(UNKNOWN_ERROR_HASH.dup)]
              end

    { 'errors' => payload }
  end

  def compound_error_hash
    error.underlying_errors.map do |underlying_error|
      with_test_mode_info(api_error_hash(underlying_error), an_error: underlying_error)
    end
  end

  def with_test_mode_info(hash, an_error: nil)
    hash['test_mode_info'] = test_mode_hash(an_error || error)
    hash
  end

  def sanitized_hash
    return_hash = unsanitized_hash
    return_hash['errors'] = unsanitized_hash['errors'].map do |error|
      error.keep_if { |k, _| allowed_keys.include? k }
    end
    return_hash
  end

  private

  def api_error_hash(error)
    {
      'detail' => error.message,
      'title'  => "CF-#{error.name}",
      'code'   => error.code,
    }
  end

  def services_error_hash
    hash = {
      'detail' => error.message,
      'title'  => "CF-#{error.class.name.demodulize}",
      'code'   => UNKNOWN_ERROR_HASH['code'],
    }
    allowed_keys.each do |key|
      hash[key] = error.to_h[key] unless error.to_h[key].nil?
    end

    hash
  end

  def test_mode_hash(an_error)
    info = {
      'detail'    => an_error.message,
      'title'     => generate_debug_title(an_error),
      'backtrace' => error.backtrace,
    }
    info.merge!(error.to_h) if error.respond_to?(:to_h)

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
