RSpec::Matchers.define :match_json do |expected|
  # RSpect matcher?
  if expected.respond_to?(:matches?)
    match do |json|
      actual = Yajl::Parser.parse(json)
      expected.matches?(actual)
    end
    # regular values or RSpec Mocks argument matchers
  else
    match do |json|
      actual = Yajl::Parser.parse(json)
      expected == actual
    end
  end
end
