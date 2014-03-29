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

RSpec::Matchers.define :match_app do |app|
  match do |state|
    state.state == app.state &&
      state.instance_count == app.instances &&
      state.memory_in_mb_per_instance == app.memory &&
      state.app_guid == app.guid &&
      state.app_name == app.name &&
      state.org_guid == app.space.organization_guid &&
      state.space_guid == app.space_guid &&
      state.space_name == app.space.name &&
      state.buildpack_name == (app.custom_buildpack_url || app.buildpack_name) &&
      state.buildpack_guid == app.buildpack_guid
  end
end

RSpec::Matchers.define :have_status_code do |expected_code|
  match do |response|
    status_code_for(response) == expected_code
  end

  failure_message_for_should do |response|
    "Expected #{expected_code} response, got:\n code: #{status_code_for(response)}\n body: \"#{response.body}\""
  end

  def status_code_for(response)
    (response.respond_to?(:code) ? response.code : response.status).to_i
  end
end
