require 'presenters/base_error_hasher'

class V2ErrorHasher < BaseErrorHasher
  UNKNOWN_ERROR_HASH = {
    'error_code' => 'UnknownError',
    'description' => 'An unknown error occurred.',
    'code' => 10001,
  }.freeze

  def unsanitized_hash
    return unknown_error_hash.dup if error.nil?

    payload = {
      'code' => 10001,
      'description' => error.message,
      'error_code' => "CF-#{error.class.name.demodulize}",
      'backtrace' => error.backtrace,
    }
    if api_error?
      payload['code'] = error.code
      payload['error_code'] = "CF-#{error.name}"
    end

    payload.merge!(error.to_h) if error.respond_to? :to_h
    payload
  end

  private

  def unknown_error_hash
    UNKNOWN_ERROR_HASH
  end

  def allowed_keys
    ['error_code', 'description', 'code', 'http']
  end
end
