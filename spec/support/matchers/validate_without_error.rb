RSpec::Matchers.define :validate_without_error do |validation_result|
  match do |validator|
    validator.validate
    @errors = validation_result.errors
    @errors.empty?
  end

  failure_message do |_|
    "Expected validator to pass without errors but got #{@errors.inspect}"
  end
end
