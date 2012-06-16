# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Models::User do
  it_behaves_like "a CloudController model", {
    :required_attributes          => :guid,
    :unique_attributes            => :guid,
    :many_to_zero_or_more => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :billing_managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :audited_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :app_spaces    => lambda { |user|
        org = VCAP::CloudController::Models::Organization.make
        user.add_organization(org)
        VCAP::CloudController::Models::AppSpace.make(:organization => org)
      }
    }
  }
end
end
