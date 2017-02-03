require 'presenters/base_error_hasher'

class V3ErrorHasher < BaseErrorHasher
  UNKNOWN_ERROR_HASH = {
    'title'  => 'UnknownError',
    'detail' => 'An unknown error occurred.',
    'code'   => 10001,
  }.freeze

  def unsanitized_hash
    return { 'errors' => [UNKNOWN_ERROR_HASH.dup] } if error.nil?

    payload = if api_error?
                api_error_hash
              elsif services_error?
                services_error_hash
              else
                UNKNOWN_ERROR_HASH.dup
              end
    payload['test_mode_info'] = test_mode_hash

    { 'errors' => [payload] }
  end

  def sanitized_hash
    return_hash = unsanitized_hash
    return_hash['errors'].first.keep_if { |k, _| allowed_keys.include? k }
    return_hash
  end

  private

  def api_error_hash
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

  def test_mode_hash
    debug_title = if error.respond_to?(:name)
                    "CF-#{error.name}"
                  else
                    "CF-#{error.class.name.demodulize}"
                  end

    info = {
      'detail'    => error.message,
      'title'     => debug_title,
      'backtrace' => error.backtrace,
    }
    info.merge!(error.to_h) if error.respond_to?(:to_h)

    info
  end

  def allowed_keys
    ['title', 'detail', 'code']
  end
end
