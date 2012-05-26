# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::User do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/users",
    :model                => VCAP::CloudController::Models::User,
    :basic_attributes     => :guid,
    :required_attributes  => :guid,
    :unique_attributes    => :guid,
    :many_to_many_collection_ids => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :billing_managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :app_spaces    => lambda { |user|
         org = user.organizations.first || VCAP::CloudController::Models::Organization.make
         VCAP::CloudController::Models::AppSpace.make(:organization => org)
      }
    }
  }

end
