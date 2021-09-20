require 'presenters/base_error_hasher'

class V2ErrorHasher < BaseErrorHasher
  UNKNOWN_ERROR_HASH = {
    'error_code'  => 'UnknownError',
    'description' => 'An unknown error occurred.',
    'code'        => 10001,
  }.freeze

  def unsanitized_hash
    return UNKNOWN_ERROR_HASH.dup if error.nil?

    payload = if api_error?
                api_error_hash
              elsif structured_error?
                structured_error_hash
              else
                UNKNOWN_ERROR_HASH.dup
              end
    payload['test_mode_info'] = test_mode_hash

    payload
  end

  def sanitized_hash
    unsanitized_hash.keep_if { |k, _| allowed_keys.include?(k) }
  end

  private

  def api_error_hash
    {
      'error_code'  => generate_error_code(error),
      'description' => error.message,
      'code'        => error.code,
    }
  end

  def structured_error_hash
    hash = {
      'error_code'  => generate_error_code(error),
      'description' => error.message,
      'code'        => UNKNOWN_ERROR_HASH['code'],
    }
    hash.merge!(error.to_h.keep_if { |k, v| allowed_keys.include?(k) && !v.nil? }) if error.respond_to?(:to_h)
    hash
  end

  def test_mode_hash
    info = {
      'error_code'  => generate_error_code(error),
      'description' => error.message,
      'backtrace'   => error.backtrace,
    }
    info.merge!(error.to_h) if error.respond_to?(:to_h)
    info
  end

  def allowed_keys
    %w[error_code description code http]
  end
end
