RSpec::Matchers.define :validate_with_error do |validation_result, error|
  match do |validator|
    validator.validate
    @errors = validation_result.errors
    @errors.size == 1 && @errors.values.first == error
  end

  failure_message do |_|
    "Expected validator to fail with error #{error} but got #{@errors.inspect}"
  end
end
