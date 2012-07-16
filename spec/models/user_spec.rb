# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::User do
  it_behaves_like "a CloudController model", {
    :required_attributes          => :guid,
    :unique_attributes            => :guid,
    :many_to_zero_or_one => {
      :default_space => lambda { |user|
        org = user.organizations.first || VCAP::CloudController::Models::Organization.make
        VCAP::CloudController::Models::Space.make(:organization => org)
      }
    },
    :many_to_zero_or_more => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :billing_managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :audited_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :spaces => lambda { |user|
        org = VCAP::CloudController::Models::Organization.make
        user.add_organization(org)
        VCAP::CloudController::Models::Space.make(:organization => org)
      }
    }
  }
end
