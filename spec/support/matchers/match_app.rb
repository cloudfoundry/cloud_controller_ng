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
      problems << "event.space_guid: #{actual_event.space_guid}, app.space_guid: #{expected_app.space_guid}"
    end
    unless actual_event.space_name == expected_app.space.name
      problems << "event.space_name: #{actual_event.space_name}, app.space.name: #{expected_app.space.name}"
    end
    unless actual_event.buildpack_guid == expected_app.detected_buildpack_guid
      problems << "event.buildpack_guid: #{actual_event.buildpack_guid}, app.detected_buildpack_guid: #{expected_app.detected_buildpack_guid}"
    end
    unless actual_event.buildpack_name == (expected_app.custom_buildpack_url || expected_app.detected_buildpack_name)
      problems << "event.buildpack_name: #{actual_event.buildpack_name}, app.buildpack_name: #{expected_app.custom_buildpack_url || expected_app.detected_buildpack_name}"
    end
    problems.empty?
  end

  failure_message do |actual_event|
    "Expect event to match app, but did not. Problems were:\n" + problems.join("\n")
  end
end
