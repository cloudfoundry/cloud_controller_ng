RSpec::Matchers.define :be_recent do |expected|
  match do |actual|
    actual.should be_within(5).of(Time.now)
  end
end
