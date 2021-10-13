require 'cloud_controller/structured_error'

class BaseErrorHasher < Struct.new(:error)
  def sanitized_hash
    unsanitized_hash.keep_if { |k, _| allowed_keys.include? k }
  end

  def unsanitized_hash
    {}
  end

  def compound_error?
    error.is_a?(CloudController::Errors::CompoundError)
  end

  def api_error?
    error.respond_to?(:code)
  end

  def services_error?
    error.is_a?(StructuredError)
  end

  private

  def allowed_keys
    []
  end

  def unknown_error_hash
    raise NotImplementedError
  end
end
