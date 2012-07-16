# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::User do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/users",
    :model                => VCAP::CloudController::Models::User,
    :required_attributes  => :guid,
    :unique_attributes    => :guid,
    :many_to_one_collection_ids => {
      :default_space => lambda { |user|
        org = user.organizations.first || VCAP::CloudController::Models::Organization.make
        VCAP::CloudController::Models::Space.make(:organization => org)
      }
    },
    :many_to_many_collection_ids => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :billing_managed_organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :spaces    => lambda { |user|
         org = user.organizations.first || VCAP::CloudController::Models::Organization.make
         VCAP::CloudController::Models::Space.make(:organization => org)
      }
    }
  }

end
