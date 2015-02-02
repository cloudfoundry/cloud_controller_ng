RSpec::Matchers.define :strip_whitespace do |attribute|
  description do
    "strip #{attribute}"
  end
  match do |instance|
    instance[attribute] = ' foo '
    instance[attribute] == 'foo'
  end
end

RSpec::Matchers.define :export_attributes do |*attributes|
  failure_message do |actual|
    instance = described_class.make
    actual_keys = instance.to_hash.keys.collect(&:to_sym)
    "expected #{described_class} to have exported attributes #{expected}, got: #{actual_keys}"
  end

  failure_message_when_negated do |actual|
    instance = described_class.make
    actual_keys = instance.to_hash.keys.collect(&:to_sym)
    "expected #{described_class} to not have exported attributes #{expected}, got: #{actual_keys}"
  end

  match do |_|
    instance = described_class.make
    instance.to_hash.keys.collect(&:to_sym).sort == attributes.sort
  end
end

RSpec::Matchers.define :import_attributes do |*attributes|
  description do
    "imports #{attributes.join(', ')}"
  end

  match do |_|
    expected_attributes = described_class.import_attrs || []
    expected_attributes.sort == attributes.sort
  end
end
