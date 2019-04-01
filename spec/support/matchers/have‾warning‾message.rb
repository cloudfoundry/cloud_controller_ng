RSpec::Matchers.define :have_warning_message do |expected_message|
  match do |actual|
    unescaped_header = CGI.unescape(actual.headers['X-Cf-Warnings'])
    unescaped_header == expected_message
  end

  failure_message do |actual|
    "expected that #{actual.headers} to have a header [X-Cf-Warnings: #{expected_message}] but did not"
  end
end
