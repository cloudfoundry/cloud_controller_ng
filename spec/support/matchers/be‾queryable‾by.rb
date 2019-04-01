RSpec::Matchers.define :be_queryable_by do |attribute|
  description do
    "is queryable by #{attribute}"
  end
  match do |controller|
    controller.query_parameters.include? attribute.to_s
  end
end
