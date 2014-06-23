RSpec::Matchers.define :validate_presence do |attribute, options = {}|
  description do
    "validate presence of #{attribute}"
  end
  match do |instance|
    unless instance.valid?
      errors = instance.errors.on(attribute)
      expected_error = options[:message] || :presence
      errors && errors.include?(expected_error)
    end
  end
end
