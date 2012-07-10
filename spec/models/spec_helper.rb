# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

Dir[File.expand_path("../helpers/*", __FILE__)].each do |file|
  require file
end

RSpec.configure do |rspec_config|
  rspec_config.include VCAP::CloudController::ModelSpecHelper
end

def make_user_for_org(org)
  user = VCAP::CloudController::Models::User.make
  user.add_organization org
  org.refresh
  user
end

def make_domain_for_org(org)
  VCAP::CloudController::Models::Domain.make(:organization => org)
end

def make_user_for_app_space(app_space)
  make_user_for_org app_space.organization
end

def make_domain_for_app_space(app_space)
  make_domain_for_org app_space.organization
end

def make_app_for_service_instance(service_instance)
  app = VCAP::CloudController::Models::App.make(:app_space => service_instance.app_space)
end

def make_service_binding_for_service_instance(service_instance)
  app = VCAP::CloudController::Models::App.make(:app_space => service_instance.app_space)
  app.app_space = service_instance.app_space
  VCAP::CloudController::Models::ServiceBinding.new(:app => app,
                                                    :service_instance => service_instance,
                                                    :credentials => Sham.service_credentials)
end

def make_app_space_for_user(user)
  app_space = Models::AppSpace.make
  app_space.organization.add_user(user)
  app_space.add_developer(user)
  app_space
end

def make_user_with_default_app_space(opts = {})
  user = Models::User.make(:admin => opts.has_key?(:admin), :active => true)
  app_space = make_app_space_for_user(user)
  user.default_app_space = app_space
  user
end
