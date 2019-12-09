RSpec::Matchers.define :include_error_message do |expected_code|
  match do |response|
    error_messages = error_messages(response)
    if expected_code.is_a?(Regexp)
      error_messages.any?(a_string_matching(expected_code))
    else
      error_messages.any?(a_string_including(expected_code))
    end
  end

  failure_message do |response|
    "Expected error message: #{expected_code}, got:\n: #{error_messages(response)}"
  end

  def error_messages(response)
    JSON.parse(response.body)['errors'].map { |error| error['detail'] }
  end
end
