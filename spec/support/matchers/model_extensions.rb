RSpec::Matchers.define :strip_whitespace do |attribute|
  description do
    "strip #{attribute}"
  end
  match do |instance|
    instance[attribute] = " foo "
    instance[attribute] == "foo"
  end
end

RSpec::Matchers.define :export_attributes do |*attributes|
  description do
    "exports #{attributes.join(", ")}"
  end

  match do |_|
    instance = described_class.make
    attributes.sort!
    instance.to_hash.keys.collect(&:to_sym).sort == attributes
  end
end


RSpec::Matchers.define :import_attributes do |*attributes|
  description do
    "imports #{attributes.join(", ")}"
  end

  match do |_|
    expected_attributes = described_class.import_attrs || []
    expected_attributes.sort == attributes.sort
  end
end
