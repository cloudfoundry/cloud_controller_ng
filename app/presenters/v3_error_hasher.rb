require 'presenters/base_error_hasher'

class V3ErrorHasher < BaseErrorHasher
  UNKNOWN_ERROR_HASH = {
    'title' => 'UnknownError',
    'detail' => 'An unknown error occurred.',
    'code' => 10001,
  }.freeze

  def unsanitized_hash
    return unknown_error_hash.dup if error.nil?

    payload = {
      'code' => 10001,
      'detail' => error.message,
      'title' => "CF-#{error.class.name.demodulize}",
      'backtrace' => error.backtrace,
    }
    if api_error?
      payload['code'] = error.code
      payload['title'] = "CF-#{error.name}"
    end

    payload.merge!(error.to_h) if error.respond_to? :to_h
    { 'errors' => [payload] }
  end

  def sanitized_hash
    return unknown_error_hash unless api_error? || services_error?
    return_hash = unsanitized_hash
    return_hash['errors'].first.keep_if { |k, _| allowed_keys.include? k }
    return_hash
  end

  private

  def unknown_error_hash
    { 'errors' => [UNKNOWN_ERROR_HASH] }
  end

  def allowed_keys
    ['title', 'detail', 'code']
  end
end
