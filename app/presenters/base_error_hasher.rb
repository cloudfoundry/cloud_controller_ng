require 'cloud_controller/structured_error'

class BaseErrorHasher < Struct.new(:error)
  def unsanitized_hash
    {}
  end

  def sanitized_hash
    {}
  end

  def api_error?
    error.respond_to?(:code)
  end

  def structured_error?
    error.is_a?(StructuredError)
  end

  def generate_error_code(error)
    if error.respond_to?(:name)
      "CF-#{error.name}"
    else
      "CF-#{error.class.name.demodulize}"
    end
  end
end
