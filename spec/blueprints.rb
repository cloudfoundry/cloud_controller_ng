# Copyright (c) 2009-2012 VMware, Inc.

Sham.define do
  email               { |index| "email-#{index}@somedomain.com" }
  password            { |index| "password-#{index}" }
  crypted_password    { |index| "crypted_password-#{index}" }
  name                { |index| "name-#{index}" }
  label               { |index| "label-#{index}" }
  password            { |index| "token-#{index}" }
  token               { |index| "token-#{index}" }
  crypted_token       { |index| "cypted_token-#{index}" }
  provider            { |index| "provider-#{index}" }
  url                 { |index| "http://foo.com/url-#{index}" }
  type                { |index| "type-#{index}" }
  description         { |index| "desc-#{index}" }
  version             { |index| "version-#{index}" }
  service_credentials { |index| "service-creds-#{index}" }
  uaa_id              { |index| "uaa-id-#{index}" }
  domain              { |index| "domain-#{index}.com" }
  host                { |index| "host-#{index}" }
end

module VCAP::CloudController::Models
  User.blueprint do
    guid              { Sham.uaa_id }
  end

  Organization.blueprint do
    name              { Sham.name }
  end

  Domain.blueprint do
    name              { Sham.domain }
    organization      { Organization.make }
  end

  Route.blueprint do
    host              { Sham.host }
    domain            { Domain.make }
  end

  Space.blueprint do
    name              { Sham.name }
    organization      { Organization.make }
  end

  ServiceAuthToken.blueprint do
    label             { Sham.label }
    provider          { Sham.provider }
    crypted_token     { Sham.crypted_token }
  end

  Service.blueprint do
    label             { Sham.label }
    provider          { Sham.provider }
    url               { Sham.url }
    description       { Sham.description }
    version           { Sham.version }
  end

  ServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    space             { Space.make }
    service_plan      { ServicePlan.make }
  end

  Runtime.blueprint do
    name              { Sham.name }
    description       { Sham.description }
  end

  Framework.blueprint do
    name              { Sham.name }
    description       { Sham.description }
  end

  App.blueprint do
    name              { Sham.name }
    space             { Space.make }
    runtime           { Runtime.make }
    framework         { Framework.make }
  end

  ServiceBinding.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ServiceInstance.make }
    app               { App.make(:space => service_instance.space) }
  end

  ServicePlan.blueprint do
    name              { Sham.name }
    description       { Sham.description }
    service           { Service.make }
  end
end
