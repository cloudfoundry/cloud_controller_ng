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

RSpec::Matchers.define :validate_db_presence do |attribute|
  description do
    "validate db presence of #{attribute}"
  end
  match do |instance|
    db_schema = described_class.db.schema(described_class.table_name)
    Hash[db_schema].fetch(attribute).fetch(:allow_null) == false
  end
end
