require "securerandom"
require_relative "app_factory"

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
  long_description    { |index| "long description-#{index} over 255 characters #{"-"*255}"}
  version             { |index| "version-#{index}" }
  service_credentials { |index| { "creds-key-#{index}" => "creds-val-#{index}" } }
  binding_options     { |index| { "binding-options-#{index}" => "value-#{index}" } }
  uaa_id              { |index| "uaa-id-#{index}" }
  domain              { |index| "domain-#{index}.com" }
  host                { |index| "host-#{index}" }
  guid                { |_| "guid-#{SecureRandom.uuid}" }
  extra               { |index| "extra-#{index}"}
  instance_index      { |index| index }
  unique_id           { |index| "unique-id-#{index}" }
  status              { |_| %w[active suspended cancelled].sample(1).first }
end

module VCAP::CloudController
  User.blueprint do
    guid              { Sham.uaa_id }
  end

  Organization.blueprint do
    name              { Sham.name }
    quota_definition  { QuotaDefinition.make }
    status            { "active" }
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
        :owning_organization => space.organization,
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
    provider          { Sham.provider }
    url               { Sham.url }
    version           { Sham.version }
    unique_id         { SecureRandom.uuid }
    description do
      # Hack since Sequel does not allow two foreign keys natively
      # and putting this side effect outside memoizes the label and provider.
      # This also creates a ServiceAuthToken for v2 services despite the fact
      # that they do not use it.
      ServiceAuthToken.make(label: label, provider: provider, token: Sham.token)
      Sham.description
    end
    bindable          { true }
    active            { true }
  end

  Service.blueprint(:v1) do
  end

  Service.blueprint(:v2) do
    service_broker
    description { Sham.description } # remove hack
    provider    { '' }
    url         { nil }
    version     { nil }
  end

  ServiceInstance.blueprint do
    name        { Sham.name }
    credentials { Sham.service_credentials }
    space       { Space.make }
  end

  ManagedServiceInstance.blueprint do
    is_gateway_service { true }
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    space             { Space.make }
    service_plan      { ServicePlan.make }
    gateway_name      { Sham.guid }
  end

  UserProvidedServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    syslog_drain_url  { Sham.url }
    space             { Space.make }
    is_gateway_service { false }
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
  end

  ServiceBinding.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    app               { AppFactory.make(:space => service_instance.space) }
    syslog_drain_url  { nil }
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

  ServicePlanVisibility.blueprint do
    service_plan { ServicePlan.make }
    organization { Organization.make }
  end

  BillingEvent.blueprint do
    timestamp         { Time.now }
    organization_guid { Sham.guid }
    organization_name { Sham.name }
  end

  Event.blueprint do
    timestamp  { Time.now }
    type       { Sham.name}
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
    app_plan_name     { "free" }
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
    timestamp         { Time.now }
  end

  Task.blueprint do
    app         { AppFactory.make }
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
  end

  AppUsageEvent.blueprint do
    state { "STARTED" }
    instance_count { 1 }
    memory_in_mb_per_instance { 564 }
    app_guid { Sham.guid }
    app_name { Sham.name }
    org_guid { Sham.guid }
    space_guid { Sham.guid }
    space_name { Sham.name }
    buildpack_guid { Sham.guid }
    buildpack_name { Sham.name }
  end
end
