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
    space_guid { Space.make.guid }
  end

  PackageModel.blueprint do
    guid     { Sham.guid }
    state    { VCAP::CloudController::PackageModel::CREATED_STATE }
    type     { 'bits' }
    app_guid { AppModel.make.guid }
  end

  DropletModel.blueprint do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app_guid { AppModel.make.guid }
  end

  User.blueprint do
    guid              { Sham.uaa_id }
  end

  Organization.blueprint do
    name              { Sham.name }
    quota_definition  { QuotaDefinition.make }
    status            { 'active' }
  end

  Domain.blueprint do
    name                { Sham.domain }
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
    name                { Sham.domain }
  end

  Route.blueprint do
    space             { Space.make }

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

  ServiceAuthToken.blueprint do
    label
    provider
    token
  end

  Service.blueprint do
    label             { Sham.label }
    unique_id         { SecureRandom.uuid }
    bindable          { true }
    active            { true }
    service_broker    { ServiceBroker.make }
    description       { Sham.description } # remove hack
    provider          { '' }
    url               { nil }
    version           { nil }
  end

  Service.blueprint(:v1) do
    provider          { Sham.provider }
    url               { Sham.url }
    version           { Sham.version }
    description do
      # Hack since Sequel does not allow two foreign keys natively
      # and putting this side effect outside memoizes the label and provider.
      # This also creates a ServiceAuthToken for v2 services despite the fact
      # that they do not use it.
      ServiceAuthToken.make(label: label, provider: provider, token: Sham.token)
      Sham.description
    end

    service_broker    { nil }
  end

  Service.blueprint(:v2) do
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
    service_plan               { ServicePlan.make(:v2) }
    gateway_name               { Sham.guid }
  end

  ManagedServiceInstance.blueprint(:v1) do
    is_gateway_service { true }
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    space             { Space.make }
    service_plan      { ServicePlan.make(:v1) }
    gateway_name      { Sham.guid }
  end

  ManagedServiceInstance.blueprint(:v2) do
  end

  UserProvidedServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
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

  ServiceBinding.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    app               { AppFactory.make(space: service_instance.space) }
    syslog_drain_url  { nil }
  end

  ServiceKey.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    name               { Sham.name }
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
    service           { Service.make(:v2) }
    unique_id         { SecureRandom.uuid }
    active            { true }
  end

  ServicePlan.blueprint(:v1) do
    name              { Sham.name }
    free              { false }
    description       { Sham.description }
    service           { Service.make(:v1) }
    unique_id         { SecureRandom.uuid }
    active            { true }
  end

  ServicePlan.blueprint(:v2) do
  end

  ServicePlanVisibility.blueprint do
    service_plan { ServicePlan.make }
    organization { Organization.make }
  end

  BillingEvent.blueprint do
    timestamp         { Time.now.utc }
    organization_guid { Sham.guid }
    organization_name { Sham.name }
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

  OrganizationStartEvent.blueprint do
    BillingEvent.blueprint
  end

  AppStartEvent.blueprint do
    BillingEvent.blueprint
    space_guid        { Sham.guid }
    space_name        { Sham.name }
    app_guid          { Sham.guid }
    app_name          { Sham.name }
    app_run_id        { Sham.guid }
    app_plan_name     { 'free' }
    app_memory        { 256 }
    app_instance_count { 1 }
  end

  AppStopEvent.blueprint do
    BillingEvent.blueprint
    space_guid        { Sham.guid }
    space_name        { Sham.name }
    app_guid          { Sham.guid }
    app_name          { Sham.name }
    app_run_id        { Sham.guid }
  end

  AppEvent.blueprint do
    app               { AppFactory.make }
    instance_guid     { Sham.guid }
    instance_index    { Sham.instance_index }
    exit_status       { Random.rand(256) }
    exit_description  { Sham.description }
    timestamp         { Time.now.utc }
  end

  ServiceCreateEvent.blueprint do
    BillingEvent.blueprint
    space_guid        { Sham.guid }
    space_name        { Sham.name }
    service_instance_guid { Sham.guid }
    service_instance_name { Sham.name }
    service_guid      { Sham.guid }
    service_label     { Sham.label }
    service_provider  { Sham.provider }
    service_version   { Sham.version }
    service_plan_guid { Sham.guid }
    service_plan_name { Sham.name }
  end

  ServiceDeleteEvent.blueprint do
    BillingEvent.blueprint
    space_guid        { Sham.guid }
    space_name        { Sham.name }
    service_instance_guid { Sham.guid }
    service_instance_name { Sham.name }
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

  TestModel.blueprint do
    required_attr true
  end

  TestModelManyToOne.blueprint do
  end

  TestModelManyToMany.blueprint do
  end

  TestModelSecondLevel.blueprint do
  end
end
