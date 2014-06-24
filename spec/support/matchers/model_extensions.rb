RSpec::Matchers.define :strip_whitespace do |attribute|
  description do
    "strip #{attribute}"
  end
  match do |instance|
    instance[attribute] = " foo "
    instance[attribute] == "foo"
  end
end
