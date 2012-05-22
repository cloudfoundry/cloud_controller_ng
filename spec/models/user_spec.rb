# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::User do
  it_behaves_like "a CloudController model", {
    :required_attributes          => :id,
    :unique_attributes            => :id,
    :sensitive_attributes         => :crypted_password,
    :extra_json_attributes        => :password,
    :many_to_zero_or_more => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :billing_managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :app_spaces    => lambda { |user|
        org = VCAP::CloudController::Models::Organization.make
        user.add_organization(org)
        VCAP::CloudController::Models::AppSpace.make(:organization => org)
      }
    }
  }
end
