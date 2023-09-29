RSpec::Matchers.define :match_service_instance do |expected_service_instance|
  problems = []

  space = expected_service_instance.space
  match do |actual_event|
    unless actual_event.org_guid == space.organization_guid
      problems << "event.org_guid: #{actual_event.org_guid}, service_instance.space.organization_guid: #{space.organization_guid}"
    end
    problems << "event.space_guid: #{actual_event.space_guid}, service_instance.space.guid: #{space.guid}" unless actual_event.space_guid == space.guid
    problems << "event.space_name: #{actual_event.space_name}, service_instance.space.name: #{space.name}" unless actual_event.space_name == space.name
    unless actual_event.service_instance_guid == expected_service_instance.guid
      problems << "event.service_instance_guid: #{actual_event.service_instance_guid}, service_instance.guid: #{expected_service_instance.guid}"
    end
    unless actual_event.service_instance_name == expected_service_instance.name
      problems << "event.service_instance_name: #{actual_event.service_instance_name}, service_instance.name: #{expected_service_instance.name}"
    end
    unless actual_event.service_instance_type == expected_service_instance.type
      problems << "event.service_instance_type: #{actual_event.service_instance_type}, service_instance.type: #{expected_service_instance.type}"
    end
    problems.empty?
  end

  if expected_service_instance.type == 'managed_service_instance'
    service_plan = expected_service_instance.service_plan
    service = service_plan.service
    broker = service.service_broker
    match do |actual_event|
      unless actual_event.service_plan_guid == service_plan.guid
        problems << "event.service_plan_guid: #{actual_event.service_plan_guid}, service_instance.service_plan.guid: #{service_plan.guid}"
      end
      unless actual_event.service_plan_name == service_plan.name
        problems << "event.service_plan_name: #{actual_event.service_plan_name}, service_instance.service_plan.name: #{service_plan.name}"
      end
      problems << "event.service_guid: #{actual_event.service_guid}, service_instance.service.guid: #{service.guid}" unless actual_event.service_guid == service.guid
      problems << "event.service_label: #{actual_event.service_label}, service_instance.service.label: #{service.label}" unless actual_event.service_label == service.label
      unless actual_event.service_broker_name == broker.name
        problems << "event.service_broker_name: #{actual_event.service_broker_name}, service_instance.service_broker.name: #{broker.name}"
      end
      unless actual_event.service_broker_guid == broker.guid
        problems << "event.service_broker_guid: #{actual_event.service_broker_guid}, service_instance.service_broker.guid: #{broker.guid}"
      end
      problems.empty?
    end
  end

  failure_message do |_actual_event|
    "Expect event to match service_instance, but did not. Problems were:\n" + problems.join("\n")
  end
end
