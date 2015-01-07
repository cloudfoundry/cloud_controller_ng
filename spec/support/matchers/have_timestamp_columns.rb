RSpec::Matchers.define :have_timestamp_columns do
  description do
    'have timestamp columns'
  end
  match do |instance|
    instance.respond_to?(:created_at) && instance.respond_to?(:updated_at)
  end
end
