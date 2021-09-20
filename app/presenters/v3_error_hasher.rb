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
                     elsif structured_error?
                       structured_error_payload
                     elsif cc_standard_error?
                       standard_error_payload
                     else
                       unknown_error_payload
                     end

    { 'errors' => errors_payload }
  end

  def sanitized_hash
    hash = unsanitized_hash
    hash['errors'] = unsanitized_hash['errors'].map do |error|
      error.keep_if { |k, _| allowed_keys.include?(k) }
    end
    hash
  end

  private

  def compound_error?
    error.respond_to?(:underlying_errors)
  end

  def cc_standard_error?
    modules = get_module_hierarchy(error.class.name)
    error.is_a?(StandardError) && (modules[0] == 'CloudController' || modules[0] == 'VCAP' && modules[1] == 'CloudController')
  end

  def get_module_hierarchy(name)
    name.deconstantize.empty? ? [name.demodulize] : get_module_hierarchy(name.deconstantize) + [name.demodulize]
  end

  def compound_error_payload
    hash_api_errors(error.underlying_errors)
  end

  def api_error_payload
    hash_api_errors([error])
  end

  def structured_error_payload
    [
      with_test_mode_info(hash: structured_error_hash, an_error: error, backtrace: error.backtrace)
    ]
  end

  def standard_error_payload
    [
      with_test_mode_info(hash: standard_error_hash, an_error: error, backtrace: error.backtrace)
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
      'title'  => generate_error_code(an_error),
      'detail' => an_error.message,
      'code'   => an_error.code,
    }
  end

  def structured_error_hash
    hash = standard_error_hash
    hash.merge!(error.to_h.keep_if { |k, v| allowed_keys.include?(k) && !v.nil? }) if error.respond_to?(:to_h)
    hash
  end

  def standard_error_hash
    {
      'title' => generate_error_code(error),
      'detail' => error.message,
      'code' => UNKNOWN_ERROR_HASH['code'],
    }
  end

  def with_test_mode_info(hash:, an_error:, backtrace:)
    hash['test_mode_info'] = test_mode_hash(an_error: an_error, backtrace: backtrace)
    hash
  end

  def test_mode_hash(an_error:, backtrace:)
    info = {
      'title'     => generate_error_code(an_error),
      'detail'    => an_error.message,
      'backtrace' => backtrace,
    }
    info.merge!(an_error.to_h) if an_error.respond_to?(:to_h)
    info
  end

  def allowed_keys
    %w[title detail code]
  end
end
