RSpec::Matchers.define :json_match do |matcher|
  # RSpect matcher?
  if matcher.respond_to?(:matches?)
    match do |json|
      actual = Yajl::Parser.parse(json)
      matcher.matches?(actual)
    end
    # regular values or RSpec Mocks argument matchers
  else
    match do |json|
      actual = Yajl::Parser.parse(json)
      matcher == actual
    end
  end
end
