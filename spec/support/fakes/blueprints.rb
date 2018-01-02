require 'securerandom'
require_relative 'process_model_factory'
require_relative '../test_models'

Sham.define do
  email               { |index| "email-#{index}@somedomain.com" }
  name                { |index| "name-#{index}" }
  label               { |index| "label-#{index}" }
  token               { |index| "token-#{index}" }
  auth_username       { |index| "auth_username-#{index}" }
  auth_password       { |index| "auth_password-#{index}" }
  provider            { |index| "provider-#{index}" }
  url                 { |index| "https://foo.com/url-#{index}" }
  type                { |index| "type-#{index}" }
  description         { |index| "desc-#{index}" }
  long_description    { |index| "long description-#{index} over 255 characters #{'-' * 255}" }
  version             { |index| "version-#{index}" }
  service_credentials { |index| { "creds-key-#{index}" => "creds-val-#{index}" } }
  uaa_id              { |index| "uaa-id-#{index}" }
  domain              { |index| "domain-#{index}.example.com" }
  host                { |index| "host-#{index}" }
  guid                { |_| "guid-#{SecureRandom.uuid}" }
  extra               { |index| "extra-#{index}" }
  instance_index      { |index| index }
  unique_id           { |index| "unique-id-#{index}" }
  status              { |_| %w(active suspended cancelled).sample(1).first }
  error_message       { |index| "error-message-#{index}" }
  sequence_id         { |index| index }
  stack               { |index| "cflinuxfs-#{index}" }
end

module VCAP::CloudController
  IsolationSegmentModel.blueprint do
    guid { Sham.guid }
    name { Sham.name }
  end

  AppModel.blueprint do
    name       { Sham.name }
    space      { Space.make }
    buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(app: object.save) }
  end

  AppModel.blueprint(:docker) do
    name { Sham.name }
    space { Space.make }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
  end

  AppModel.blueprint(:buildpack) do
  end

  BuildModel.blueprint do
    guid     { Sham.guid }
    app      { AppModel.make }
    state    { VCAP::CloudController::BuildModel::STAGED_STATE }
  end

  BuildModel.blueprint(:docker) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make(droplet_guid: guid) }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
  end

  PackageModel.blueprint do
    guid     { Sham.guid }
    state    { VCAP::CloudController::PackageModel::CREATED_STATE }
    type     { 'bits' }
    app { AppModel.make }
  end

  PackageModel.blueprint(:docker) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::PackageModel::READY_STATE }
    type     { 'docker' }
    app { AppModel.make }
    docker_image { "org/image-#{Sham.guid}:latest" }
  end

  DropletModel.blueprint do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGED_STATE }
    app { AppModel.make(droplet_guid: guid) }
    droplet_hash { Sham.guid }
    sha256_checksum { Sham.guid }
    buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(droplet: object.save) }
  end

  DropletModel.blueprint(:docker) do
    guid { Sham.guid }
    droplet_hash { nil }
    sha256_checksum { nil }
    state { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make(droplet_guid: guid) }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
  end

  DeploymentModel.blueprint do
    state { VCAP::CloudController::DeploymentModel::DEPLOYING_STATE }
    app { AppModel.make }
    droplet { DropletModel.make(app: app) }
  end

  TaskModel.blueprint do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app: app) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::RUNNING_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  TaskModel.blueprint(:running) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app: app) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::RUNNING_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  TaskModel.blueprint(:canceling) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app: app) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::CANCELING_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  TaskModel.blueprint(:succeeded) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app: app) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::SUCCEEDED_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  TaskModel.blueprint(:pending) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app: app) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::PENDING_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  PollableJobModel.blueprint do
    guid { Sham.guid }
    operation { 'some.job' }
    state { 'COMPLETE' }
    resource_guid { Sham.guid }
    resource_type { 'some' }
  end

  User.blueprint do
    guid { Sham.uaa_id }
  end

  Organization.blueprint do
    name              { Sham.name }
    quota_definition  { QuotaDefinition.make }
    status            { 'active' }
  end

  Domain.blueprint do
    name { Sham.domain }
  end

  PrivateDomain.blueprint do
    name                { Sham.domain }
    owning_organization { Organization.make }
  end

  SharedDomain.blueprint do
    name { Sham.domain }
  end

  Route.blueprint do
    space { Space.make }

    domain do
      PrivateDomain.make(
        owning_organization: space.organization,
      )
    end

    host { Sham.host }
  end

  Space.blueprint do
    name              { Sham.name }
    organization      { Organization.make }
  end

  Service.blueprint do
    label                 { Sham.label }
    unique_id             { SecureRandom.uuid }
    bindable              { true }
    active                { true }
    service_broker        { ServiceBroker.make }
    description           { Sham.description } # remove hack
    extra                 { '{"shareable": true}' }
    instances_retrievable { false }
    bindings_retrievable  { false }
  end

  Service.blueprint(:routing) do
    requires { ['route_forwarding'] }
  end

  Service.blueprint(:volume_mount) do
    requires { ['volume_mount'] }
  end

  ServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    space             { Space.make }
  end

  ManagedServiceInstance.blueprint do
    is_gateway_service         { true }
    name                       { Sham.name }
    credentials                { Sham.service_credentials }
    space                      { Space.make }
    service_plan               { ServicePlan.make }
    gateway_name               { Sham.guid }
  end

  ManagedServiceInstance.blueprint(:routing) do
    service_plan { ServicePlan.make(:routing) }
  end

  ManagedServiceInstance.blueprint(:volume_mount) do
    service_plan { ServicePlan.make(:volume_mount) }
  end

  UserProvidedServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    syslog_drain_url  { Sham.url }
    space             { Space.make }
    is_gateway_service { false }
  end

  UserProvidedServiceInstance.blueprint(:routing) do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    route_service_url { Sham.url }
    syslog_drain_url  { Sham.url }
    space             { Space.make }
    is_gateway_service { false }
  end

  ServiceInstanceOperation.blueprint do
    type                      { 'create' }
    state                     { 'succeeded' }
    description               { 'description goes here' }
    updated_at                { Time.now.utc }
  end

  Stack.blueprint do
    name              { Sham.name }
    description       { Sham.description }
  end

  # if you want to create a process with droplet, use ProcessModelFactory.make
  # This is because the lack of factory hooks in Machinist.
  ProcessModel.blueprint do
    instances { 1 }
    type { 'web' }
    diego { true }
    app { AppModel.make }
  end

  ProcessModel.blueprint(:process) do
    app { AppModel.make }
    diego { true }
    instances { 1 }
    type { Sham.name }
    metadata { {} }
  end

  ProcessModel.blueprint(:diego_runnable) do
    app { AppModel.make(droplet: DropletModel.make) }
    diego { true }
    instances { 1 }
    type { Sham.name }
    metadata { {} }
    state { 'STARTED' }
  end

  ProcessModel.blueprint(:docker) do
    app { AppModel.make(:docker) }
    diego { true }
    instances { 1 }
    type { Sham.name }
    metadata { {} }
  end

  RouteBinding.blueprint do
    service_instance { ManagedServiceInstance.make(:routing) }
    route { Route.make space: service_instance.space }
    route_service_url { Sham.url }
  end

  ServiceBinding.blueprint do
    credentials { Sham.service_credentials }
    service_instance { ManagedServiceInstance.make }
    app { AppModel.make(space: service_instance.space) }
    syslog_drain_url { nil }
    type { 'app' }
    name { nil }
  end

  ServiceKey.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    name { Sham.name }
  end

  ServiceKey.blueprint(:credhub_reference) do
    credentials       { { 'credhub-ref' => Sham.name } }
    service_instance  { ManagedServiceInstance.make }
    name { Sham.name }
  end

  ServiceBroker.blueprint do
    name              { Sham.name }
    broker_url        { Sham.url }
    auth_username     { Sham.auth_username }
    auth_password     { Sham.auth_password }
  end

  ServiceDashboardClient.blueprint do
    uaa_id          { Sham.name }
    service_broker  { ServiceBroker.make }
  end

  ServicePlan.blueprint do
    name              { Sham.name }
    free              { false }
    description       { Sham.description }
    service           { Service.make }
    unique_id         { SecureRandom.uuid }
    active            { true }
  end

  ServicePlan.blueprint(:routing) do
    service { Service.make(:routing) }
  end

  ServicePlan.blueprint(:volume_mount) do
    service { Service.make(:volume_mount) }
  end

  ServicePlanVisibility.blueprint do
    service_plan { ServicePlan.make }
    organization { Organization.make }
  end

  Event.blueprint do
    timestamp  { Time.now.utc }
    type       { Sham.name }
    actor      { Sham.guid }
    actor_type { Sham.name }
    actor_name { Sham.name }
    actee      { Sham.guid }
    actee_type { Sham.name }
    actee_name { Sham.name }
    space      { Space.make }
  end

  AppEvent.blueprint do
    app               { ProcessModelFactory.make }
    instance_guid     { Sham.guid }
    instance_index    { Sham.instance_index }
    exit_status       { Random.rand(256) }
    exit_description  { Sham.description }
    timestamp         { Time.now.utc }
  end

  QuotaDefinition.blueprint do
    name { Sham.name }
    non_basic_services_allowed { true }
    total_reserved_route_ports { 5 }
    total_services { 60 }
    total_routes { 1_000 }
    memory_limit { 20_480 } # 20 GB
  end

  Buildpack.blueprint do
    name { Sham.name }
    stack { Stack.make.name }
    key { Sham.guid }
    position { 0 }
    enabled { true }
    filename { Sham.name }
    locked { false }
  end

  Buildpack.blueprint(:nil_stack) do
    stack { nil }
  end

  BuildpackLifecycleDataModel.blueprint do
    buildpacks { nil }
    stack { Stack.make.name }
  end

  BuildpackLifecycleBuildpackModel.blueprint do
    admin_buildpack_name { Buildpack.make(name: 'ruby').name }
    buildpack_url { nil }
  end

  BuildpackLifecycleBuildpackModel.blueprint(:custom_buildpack) do
    admin_buildpack_name { nil }
    buildpack_url { 'http://example.com/temporary' }
  end

  AppUsageEvent.blueprint do
    state { 'STARTED' }
    package_state { 'STAGED' }
    instance_count { 1 }
    memory_in_mb_per_instance { 564 }
    app_guid { Sham.guid }
    app_name { Sham.name }
    org_guid { Sham.guid }
    space_guid { Sham.guid }
    space_name { Sham.name }
    buildpack_guid { Sham.guid }
    buildpack_name { Sham.name }
    process_type { 'web' }
  end

  ServiceUsageEvent.blueprint do
    state { 'CREATED' }
    org_guid { Sham.guid }
    space_guid { Sham.guid }
    space_name { Sham.name }
    service_instance_guid { Sham.guid }
    service_instance_name { Sham.name }
    service_instance_type { Sham.type }
    service_plan_guid { Sham.guid }
    service_plan_name { Sham.name }
    service_guid { Sham.guid }
    service_label { Sham.label }
  end

  SecurityGroup.blueprint do
    name { Sham.name }
    rules do
      [
        {
          'protocol' => 'udp',
          'ports' => '8080',
          'destination' => '198.41.191.47/1',
        }
      ]
    end
    staging_default { false }
  end

  SpaceQuotaDefinition.blueprint do
    name { Sham.name }
    non_basic_services_allowed { true }
    total_services { 60 }
    total_service_keys { 600 }
    total_routes { 1_000 }
    memory_limit { 20_480 } # 20 GB
    organization { Organization.make }
  end

  EnvironmentVariableGroup.blueprint do
    name { "runtime-#{Sham.instance_index}" }
    environment_json do
      {
        'MOTD' => 'Because of your smile, you make life more beautiful.',
        'COROPRATE_PROXY_SERVER' => 'abc:8080',
      }
    end
  end

  FeatureFlag.blueprint do
    name { 'user_org_creation' }
    enabled { false }
    error_message { Sham.error_message }
  end

  RouteMappingModel.blueprint do
    app { AppModel.make }
    route { Route.make(space: app.space) }
    process_type { 'web' }
    app_port { -1 }
  end

  RequestCount.blueprint do
    valid_until { Time.now.utc }
  end

  TestModel.blueprint do
    required_attr true
  end

  TestModelManyToOne.blueprint do
  end

  TestModelManyToMany.blueprint do
  end

  TestModelSecondLevel.blueprint do
  end

  TestModelRedact.blueprint do
  end
end
