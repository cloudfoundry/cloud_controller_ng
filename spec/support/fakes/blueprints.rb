require 'securerandom'
require_relative 'app_factory'
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
  binding_options     { |index| { "binding-options-#{index}" => "value-#{index}" } }
  uaa_id              { |index| "uaa-id-#{index}" }
  domain              { |index| "domain-#{index}.example.com" }
  host                { |index| "host-#{index}" }
  guid                { |_| "guid-#{SecureRandom.uuid}" }
  extra               { |index| "extra-#{index}" }
  instance_index      { |index| index }
  unique_id           { |index| "unique-id-#{index}" }
  status              { |_| %w(active suspended cancelled).sample(1).first }
  error_message       { |index| "error-message-#{index}" }
end

module VCAP::CloudController
  AppModel.blueprint do
    guid       { Sham.guid }
    name       { Sham.name }
    space      { Space.make }
  end

  AppModel.blueprint(:buildpack) do
    guid       { Sham.guid }
    name       { Sham.name }
    space { Space.make }
    buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(app: object.save) }
  end

  AppModel.blueprint(:docker) do
  end

  PackageModel.blueprint do
    guid     { Sham.guid }
    state    { VCAP::CloudController::PackageModel::CREATED_STATE }
    type     { 'bits' }
    app { AppModel.make }
  end

  PackageModel.blueprint(:docker) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::PackageModel::CREATED_STATE }
    type     { 'docker' }
    app { AppModel.make }
    docker_data { PackageDockerDataModel.create(package: object.save, image: "org/image-#{Sham.guid}:latest") }
  end

  DropletModel.blueprint do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make }
    memory_limit { 123 }
  end

  DropletModel.blueprint(:docker) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make }
    memory_limit { 123 }
  end

  DropletModel.blueprint(:buildpack) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make }
    memory_limit { 123 }
    buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(droplet: object.save) }
  end

  TaskModel.blueprint do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app_guid: app.guid) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::RUNNING_STATE }
    memory_in_mb { 256 }
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

  Droplet.blueprint do
    app { App.make }
    droplet_hash { Sham.guid }
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
    label             { Sham.label }
    unique_id         { SecureRandom.uuid }
    bindable          { true }
    active            { true }
    service_broker    { ServiceBroker.make }
    description       { Sham.description } # remove hack
  end

  Service.blueprint(:routing) do
    requires { ['route_forwarding'] }
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

  # if you want to create an app with droplet, use AppFactory.make
  # This is because the lack of factory hooks in Machinist.
  App.blueprint do
    name              { Sham.name }
    space             { Space.make }
    stack             { Stack.make }
    instances         { 1 }
    type              { 'web' }
  end

  RouteBinding.blueprint do
    service_instance { ManagedServiceInstance.make(:routing) }
    route { Route.make space: service_instance.space }
    route_service_url { Sham.url }
  end

  RouteMapping.blueprint do
    app { AppFactory.make }
    route { Route.make(space: app.space) }
  end

  ServiceBinding.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    app               { AppFactory.make(space: service_instance.space) }
    syslog_drain_url  { nil }
  end

  ServiceBindingModel.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    app { AppModel.make(space_guid: service_instance.space.guid) }
    type { 'app' }
  end

  ServiceKey.blueprint do
    credentials       { Sham.service_credentials }
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
    app               { AppFactory.make }
    instance_guid     { Sham.guid }
    instance_index    { Sham.instance_index }
    exit_status       { Random.rand(256) }
    exit_description  { Sham.description }
    timestamp         { Time.now.utc }
  end

  QuotaDefinition.blueprint do
    name { Sham.name }
    non_basic_services_allowed { true }
    total_services { 60 }
    total_routes { 1_000 }
    memory_limit { 20_480 } # 20 GB
  end

  Buildpack.blueprint do
    name { Sham.name }
    key { Sham.guid }
    position { 0 }
    enabled { true }
    filename { Sham.name }
    locked { false }
  end

  BuildpackLifecycleDataModel.blueprint do
    buildpack { Sham.name }
    stack { Sham.name }
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
