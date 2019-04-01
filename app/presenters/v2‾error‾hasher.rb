require 'presenters/base_error_hasher'

class V2ErrorHasher < BaseErrorHasher
  UNKNOWN_ERROR_HASH = {
    'error_code'  => 'UnknownError',
    'description' => 'An unknown error occurred.',
    'code'        => 10001,
  }.freeze

  def unsanitized_hash
    return unknown_error_hash.dup if error.nil?

    payload = if api_error?
                api_error_hash
              elsif services_error?
                services_error_hash
              else
                unknown_error_hash.dup
              end
    payload['test_mode_info'] = test_mode_hash

    payload
  end

  private

  def api_error_hash
    {
      'description' => error.message,
      'error_code'  => "CF-#{error.name}",
      'code'        => error.code,
    }
  end

  def services_error_hash
    hash = {
      'description' => error.message,
      'error_code'  => "CF-#{error.class.name.demodulize}",
      'code'        => UNKNOWN_ERROR_HASH['code'],
    }
    allowed_keys.each do |key|
      hash[key] = error.to_h[key] unless error.to_h[key].nil?
    end

    hash
  end

  def test_mode_hash
    debug_error_code = if error.respond_to?(:name)
                         "CF-#{error.name}"
                       else
                         "CF-#{error.class.name.demodulize}"
                       end

    info = {
      'description' => error.message,
      'error_code'  => debug_error_code,
      'backtrace'   => error.backtrace,
    }
    info.merge!(error.to_h) if error.respond_to?(:to_h)

    info
  end

  def unknown_error_hash
    UNKNOWN_ERROR_HASH
  end

  def allowed_keys
    ['error_code', 'description', 'code', 'http']
  end
end
