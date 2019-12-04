RSpec::Matchers.define :have_status_code do |expected_code|
  match do |response|
    status_code_for(response) == expected_code
  end

  failure_message do |response|
    body = JSON.pretty_generate(JSON.parse(response.body))
    "Expected #{expected_code} response, got:\n code: #{status_code_for(response)}\n body: \"#{body}\""
  rescue JSON::ParserError
    "Expected #{expected_code} response, got:\n code: #{status_code_for(response)}\n unparsed body: \"#{response.body}\""
  end

  def status_code_for(response)
    (response.respond_to?(:code) ? response.code : response.status).to_i
  end
end
