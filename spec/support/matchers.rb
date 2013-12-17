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
      state.space_name == app.space.name
  end
end
