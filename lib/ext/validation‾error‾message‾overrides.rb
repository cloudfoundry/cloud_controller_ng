class ::Membrane::Schemas::Regexp::MatchValidator
  def fail!(regexp, object)
    emsg = if regexp.respond_to?(:default_error_message)
             regexp.default_error_message
           else
             "Value #{object} doesn't match regexp #{regexp.inspect}"
           end
    raise ::Membrane::SchemaValidationError.new(emsg)
  end
end
