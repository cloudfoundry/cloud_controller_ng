require_relative '../../spec/support/fakes/blueprints'

module VCAP::CloudController
  FIXED_ORGS = [
    { name: 'sales-org', guid: Sham.guid },
    { name: 'engineering-org', guid: Sham.guid },
    { name: 'marketing-org', guid: Sham.guid }
  ].freeze

  FIXED_SPACES = FIXED_ORGS.map do |org|
    [
      { name: "#{org[:name]}-dev", guid: Sham.guid, org: org },
      { name: "#{org[:name]}-staging", guid: Sham.guid, org: org },
      { name: "#{org[:name]}-prod", guid: Sham.guid, org: org }
    ]
  end.flatten

  BUILDPACKS = {
    'ruby_buildpack' => Sham.guid,
    'nodejs_buildpack' => Sham.guid,
    'go_buildpack' => Sham.guid
  }.freeze

  SERVICE_PLANS = {
    'small' => Sham.guid,
    'medium' => Sham.guid,
    'large' => Sham.guid,
    'premium' => Sham.guid
  }.freeze

  SERVICE_BROKERS = {
    'aws-service-broker' => Sham.guid,
    'gcp-service-broker' => Sham.guid,
    'azure-service-broker' => Sham.guid
  }.freeze

  SERVICES = {
    'postgresql' => Sham.guid,
    'redis' => Sham.guid,
    'rabbitmq' => Sham.guid,
    'mongodb' => Sham.guid
  }.freeze

  SERVICE_INSTANCE_TYPES = %w[
    managed_service_instance
    user_provided_service_instance
  ].freeze

  SERVICE_INSTANCE_NAMES = {
    'postgresql' => %w[users-db orders-db inventory-db],
    'redis' => %w[session-cache api-cache queue-cache],
    'rabbitmq' => %w[event-queue worker-queue notification-queue],
    'mongodb' => %w[analytics-store metrics-store logs-store]
  }.freeze

  APP_NAMES = {
    'frontend-ui' => Sham.guid,
    'backend-api' => Sham.guid,
    'auth-service' => Sham.guid,
    'payment-processor' => Sham.guid,
    'notification-service' => Sham.guid,
    'user-service' => Sham.guid,
    'order-service' => Sham.guid,
    'inventory-service' => Sham.guid,
    'search-service' => Sham.guid,
    'analytics-service' => Sham.guid
  }.freeze

  CURRENT_TIME = Time.new(2025, 1, 10, 9, 0, 0)
  THREE_DAYS_AGO = CURRENT_TIME - 3.days
  TWO_YEARS_AGO = CURRENT_TIME - (2 * 365 * 24 * 3600)

  def self.generate_stop_time(start_time)
    max_possible_hours = ((CURRENT_TIME - start_time) / 3600).floor
    min_hours = 20
    max_hours = [600, max_possible_hours].min

    hours_to_add = if max_possible_hours < min_hours
                     max_possible_hours
                   else
                     rand(min_hours..max_hours)
                   end

    start_time + hours_to_add.hours
  end

  app_events_to_create = []

  100.times do
    space = FIXED_SPACES.sample
    buildpack_name = BUILDPACKS.keys.sample
    app_name = APP_NAMES.keys.sample
    app_guid = Sham.guid

    common_app_attrs = {
      memory_in_mb_per_instance: [128, 256, 512, 1024].sample,
      previous_memory_in_mb_per_instance: nil,
      instance_count: rand(1..10),
      previous_instance_count: nil,
      process_type: 'web',
      parent_app_guid: APP_NAMES[app_name],
      parent_app_name: app_name,
      app_guid: app_guid,
      app_name: app_name,
      space_name: space[:name],
      space_guid: space[:guid],
      org_guid: space[:org][:guid],
      buildpack_guid: BUILDPACKS[buildpack_name],
      buildpack_name: buildpack_name,
      package_state: 'STAGED',
      previous_package_state: nil,
      task_guid: nil,
      task_name: nil,
      previous_state: nil
    }

    start_time = Time.at(rand(TWO_YEARS_AGO.to_i..THREE_DAYS_AGO.to_i))
    stop_time = generate_stop_time(start_time)

    started_event = {
      attributes: common_app_attrs.merge(
        state: 'STARTED',
        created_at: start_time
      ),
      created_at: start_time
    }

    stopped_event = {
      attributes: common_app_attrs.merge(
        state: 'STOPPED',
        previous_state: 'STARTED',
        created_at: stop_time
      ),
      created_at: stop_time
    }

    app_events_to_create.push(started_event, stopped_event)
  end

  service_events_to_create = []

  100.times do
    space = FIXED_SPACES.sample
    service_plan_name = SERVICE_PLANS.keys.sample
    service_broker_name = SERVICE_BROKERS.keys.sample
    service_label = SERVICES.keys.sample
    service_instance_type = SERVICE_INSTANCE_TYPES.sample
    service_instance_name = SERVICE_INSTANCE_NAMES[service_label].sample
    service_instance_guid = Sham.guid

    common_service_attrs = {
      space_name: space[:name],
      space_guid: space[:guid],
      org_guid: space[:org][:guid],
      service_instance_guid: service_instance_guid,
      service_instance_name: service_instance_name,
      service_instance_type: service_instance_type,
      service_plan_guid: SERVICE_PLANS[service_plan_name],
      service_plan_name: service_plan_name,
      service_guid: SERVICES[service_label],
      service_label: service_label,
      service_broker_guid: SERVICE_BROKERS[service_broker_name],
      service_broker_name: service_broker_name
    }

    creation_time = Time.at(rand(TWO_YEARS_AGO.to_i..THREE_DAYS_AGO.to_i))
    deletion_time = generate_stop_time(creation_time)

    created_event = {
      attributes: common_service_attrs.merge(
        state: 'CREATED',
        created_at: creation_time
      ),
      created_at: creation_time
    }

    deleted_event = {
      attributes: common_service_attrs.merge(
        state: 'DELETED',
        created_at: deletion_time
      ),
      created_at: deletion_time
    }

    service_events_to_create.push(created_event, deleted_event)
  end

  events = (app_events_to_create + service_events_to_create).sort_by { |e| e[:created_at] }

  events.each do |event|
    if event[:attributes][:service_instance_guid]
      ServiceUsageEvent.make(**event[:attributes])
    else
      AppUsageEvent.make(**event[:attributes])
    end
  end
end
