class BaseErrorHasher < Struct.new(:error)
  def sanitized_hash
    return unknown_error_hash unless api_error? || services_error?
    unsanitized_hash.keep_if { |k, _| allowed_keys.include? k }
  end

  def unsanitized_hash
    {}
  end

  def api_error?
    error.is_a?(CloudController::Errors::ApiError) || error.respond_to?(:error_code)
  end

  def services_error?
    error.respond_to?(:source)
  end

  private

  def allowed_keys
    []
  end

  def unknown_error_hash
    raise NotImplementedError
  end
end
