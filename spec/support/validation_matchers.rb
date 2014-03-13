RSpec::Matchers.define :validate_with_error do |validation_result, error|
  match do |validator|
    validator.validate
    @errors = validation_result.errors
    @errors.size == 1 && @errors.values.first == error
  end

  failure_message_for_should do |_|
    "Expected validator to fail with error #{error} but got #{@errors.inspect}"
  end
end

RSpec::Matchers.define :validate_without_error do |validation_result|
  match do |validator|
    validator.validate
    @errors = validation_result.errors
    @errors.empty?
  end

  failure_message_for_should do |_|
    "Expected validator to pass without errors but got #{@errors.inspect}"
  end
end
