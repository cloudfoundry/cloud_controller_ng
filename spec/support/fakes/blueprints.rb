# Copyright (c) 2009-2012 VMware, Inc.

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
  service_credentials { |index|
    { "creds-key-#{index}" => "creds-val-#{index}" }
  }
  binding_options     { |index|
    {"binding-options-#{index}" => "value-#{index}"}
  }
  uaa_id              { |index| "uaa-id-#{index}" }
  domain              { |index| "domain-#{index}.com" }
  host                { |index| "host-#{index}" }
  guid                { |index| "guid-#{index}" }
  extra               { |index| "extra-#{index}"}
  instance_index      { |index| index }
  unique_id           { |index| "unique-id-#{index}" }
  status              { |_| ["active", "suspended", "cancelled"].sample(1).first }
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

  Domain.blueprint do
    name                { Sham.domain }
    wildcard            { false }
    owning_organization { Organization.make }
  end

  Route.blueprint do
    space             { Space.make }

    domain do
      d = Domain.make(
        :owning_organization => space.organization,
        :wildcard => true
      )
      space.add_domain(d)
      d
    end

    host do
      if domain && domain.wildcard
        Sham.host
      else
        ""
      end
    end
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
    unique_id         { "#{provider}_#{label}" }
    description do
      # Hack since Sequel does not allow two foreign keys natively
      # and putting this side effect outside memoizes the label and provider.
      # This also creates a ServiceAuthToken for v2 services despite the fact
      # that they do not use it.
      ServiceAuthToken.make(:label => label, :provider => provider, :token => Sham.token)
      Sham.description
    end
    bindable          { true }
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
    space             { Space.make }
    is_gateway_service { false }
  end

  Stack.blueprint do
    name              { Sham.name }
    description       { Sham.description }
  end

  App.blueprint do
    name              { Sham.name }
    space             { Space.make }
    stack             { Stack.make }
    droplet_hash      { Sham.guid }
  end

  ServiceBinding.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    app               { App.make(:space => service_instance.space) }
  end

  ServiceBroker.blueprint do
    name              { Sham.name }
    broker_url        { Sham.url }
    auth_username     { Sham.auth_username }
    auth_password     { Sham.auth_password }
  end

  ServicePlan.blueprint do
    name              { Sham.name }
    free              { false }
    description       { Sham.description }
    service           { Service.make }
    unique_id         { [service.provider, service.label, name].join("_") }
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
    actee      { Sham.guid }
    actee_type { Sham.name }
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
    app               { App.make }
    instance_guid     { Sham.guid }
    instance_index    { Sham.instance_index }
    exit_status       { Random.rand(256) }
    exit_description  { Sham.description }
    timestamp         { Time.now }
  end

  Task.blueprint do
    app         { App.make }
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
    memory_limit { 20480 } # 20 GB
    trial_db_allowed { false }
  end

  Buildpack.blueprint do
    name { Sham.name }
    key { Sham.guid }
    priority { 0 }
  end
end
