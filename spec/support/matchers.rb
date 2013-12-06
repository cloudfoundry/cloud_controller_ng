require 'rspec/expectations'

RSpec::Matchers.define :be_a_guid do
  match do |actual|
    actual.to_s =~ /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/i
  end
end

RSpec::Matchers.define :be_a_deprecated_response do |_|
  match do |actual|
    actual.headers["X-Cf-Warning"] == "Endpoint deprecated"
  end

  failure_message_for_should do |actual|
    "expected that #{actual.headers} to have a header [X-Cf-Warning: Endpoint deprecated] but did not"
  end
end
