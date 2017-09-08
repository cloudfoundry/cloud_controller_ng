RSpec::Matchers.define :have_error_message do |expected_code|
  match do |response|
    error_message = error_message(response)
    if expected_code.is_a?(Regexp)
      error_message.match(expected_code)
    else
      error_message.include?(expected_code)
    end
  end

  failure_message do |response|
    "Expected error message: #{expected_code}, got:\n: #{error_message(response)}"
  end

  def error_message(response)
    JSON.parse(response.body)['errors'][0]['detail']
  end
end
