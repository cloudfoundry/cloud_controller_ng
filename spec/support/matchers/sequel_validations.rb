RSpec::Matchers.define :validate_presence do |attribute, options={}|
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

RSpec::Matchers.define :validate_not_null do |attribute, options={}|
  description do
    "validate #{attribute} is not null"
  end
  match do |instance|
    unless instance.valid?
      errors = instance.errors.on(attribute)
      expected_error = options[:message] || :not_null
      errors && errors.include?(expected_error)
    end
  end
end

RSpec::Matchers.define :validate_db_presence do |attribute|
  description do
    "validate db presence of #{attribute}"
  end
  match do |instance|
    db_schema = described_class.db.schema(described_class.table_name)
    Hash[db_schema].fetch(attribute).fetch(:allow_null) == false
  end
end

RSpec::Matchers.define :validate_uniqueness do |*attributes|
  options = attributes.extract_options!
  make_arguments = options.delete(:make)
  attributes.flatten!
  description do
    "validate uniqueness of #{Array.wrap(attributes).join(' and ')}"
  end
  match do |_|
    source_obj = described_class.make(*make_arguments)
    duplicate_object = described_class.make(*make_arguments)
    Array.wrap(attributes).each do |attr|
      duplicate_object[attr] = source_obj[attr]
    end
    unless duplicate_object.valid?
      errors_key = attributes.length > 1 ? attributes : attributes.first
      errors = duplicate_object.errors.on(errors_key)
      expected_error = options[:message] || :unique
      errors && errors.include?(expected_error)
    end
  end
end

RSpec::Matchers.define :validates_includes do |values, attribute, options={}|
  description do
    "validate includes of #{attribute} with #{values}"
  end
  match do |instance|
    allow(instance).to receive(:validates_includes)
    instance.valid?
    expect(instance).to have_received(:validates_includes).with(values, attribute, options)
  end
end
