RSpec::Matchers.define :be_a_deprecated_response do |_|
  match do |actual|
    unescaped_header = CGI.unescape(actual.headers["X-Cf-Warnings"])
    unescaped_header == "Endpoint deprecated"
  end

  failure_message do |actual|
    "expected that #{actual.headers} to have a header [X-Cf-Warnings: Endpoint deprecated] but did not"
  end
end
