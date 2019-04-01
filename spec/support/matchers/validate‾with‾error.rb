RSpec::Matchers.define :validate_with_error do |validation_result, field, error|
  match do |validator|
    validator.validate
    @errors = validation_result.errors
    field_errors = @errors.on(field)
    field_errors && field_errors.include?(error)
  end

  failure_message do |_|
    "Expected validator to fail with error #{error} but got #{@errors.inspect}"
  end
end
