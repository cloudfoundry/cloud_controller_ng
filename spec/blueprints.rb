# Copyright (c) 2009-2011 VMware, Inc.

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
end

module VCAP::CloudController::Models
  User.blueprint do
    email             { Sham.email }
    crypted_password  { Sham.crypted_password }
  end

  Organization.blueprint do
    name              { Sham.name }
  end

  AppSpace.blueprint do
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
    type              { Sham.type }
    description       { Sham.description }
    version           { Sham.version }
  end

  ServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    app_space         { AppSpace.make }
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
    app_space         { AppSpace.make }
    runtime           { Runtime.make }
    framework         { Framework.make }
  end

  ServiceBinding.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ServiceInstance.make }
    app               { App.make(:app_space => service_instance.app_space) }
  end

  ServicePlan.blueprint do
    name              { Sham.name }
    description       { Sham.description }
    service           { Service.make }
  end
end
