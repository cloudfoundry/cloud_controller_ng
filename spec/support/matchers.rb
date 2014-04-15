require 'rspec/expectations'

RSpec::Matchers.define :be_a_guid do
  match do |actual|
    actual.to_s =~ /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/i
  end
end

RSpec::Matchers.define :be_a_deprecated_response do |_|
  match do |actual|
    unescaped_header = CGI.unescape(actual.headers["X-Cf-Warnings"])
    unescaped_header == "Endpoint deprecated"
  end

  failure_message_for_should do |actual|
    "expected that #{actual.headers} to have a header [X-Cf-Warnings: Endpoint deprecated] but did not"
  end
end

RSpec::Matchers.define :match_app do |expected_app|
  problems = []
  match do |actual_event|
    unless actual_event.state == expected_app.state
      problems << "event.state: #{actual_event.state}, app.state: #{expected_app.state}"
    end
    unless actual_event.instance_count == expected_app.instances
      problems << "event.instance_count: #{actual_event.instance_count}, app.instances: #{expected_app.instance_count}"
    end
    unless actual_event.memory_in_mb_per_instance == expected_app.memory
      problems << "event.memory_in_mb_per_instance: #{actual_event.memory_in_mb_per_instance}, app.memory: #{expected_app.memory}"
    end
    unless actual_event.app_guid == expected_app.guid
      problems << "event.app_guid: #{actual_event.app_guid}, app.guid: #{expected_app.guid}"
    end
    unless actual_event.app_name == expected_app.name
      problems << "event.app_name: #{actual_event.app_name}, app.name: #{expected_app.name}"
    end
    unless actual_event.org_guid == expected_app.organization.guid
      problems << "event.org_guid: #{actual_event.org_guid}, app.space.organization_guid: #{expected_app.organization.guid}"
    end
    unless actual_event.space_guid == expected_app.space_guid
      problems << "event.space_name: #{actual_event.space_name}, app.space_guid: #{expected_app.space_guid}"
    end
    unless actual_event.space_name == expected_app.space.name
      problems << "event.buildpack_guid: #{actual_event.buildpack_guid}, app.space.name: #{expected_app.space.name}"
    end
    unless actual_event.buildpack_guid == expected_app.detected_buildpack_guid
      problems << "event.buildpack_guid: #{actual_event.buildpack_guid}, app.detected_buildpack_guid: #{expected_app.detected_buildpack_guid}"
    end
    unless actual_event.buildpack_name == (expected_app.custom_buildpack_url || expected_app.detected_buildpack_name)
      problems << "event.buildpack_name: #{actual_event.buildpack_name}, app.buildpack_name: #{expected_app.custom_buildpack_url || expected_app.detected_buildpack_name}"
    end
    problems.empty?
  end

  failure_message_for_should do |actual_event|
    "Expect event to match app, but did not. Problems were:\n" + problems.join("\n")
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

RSpec::Matchers.define :allow_op_on_object do |op, object|
  match do |access|
    access.can?("#{op}_with_token".to_sym, object) && access.can?(op, object)
  end

  failure_message_for_should do
    "Expected to be able to perform operation #{op} on object #{object}"
  end
end
