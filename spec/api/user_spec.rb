# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::User do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/users",
      :model                => Models::User,
      :required_attributes  => :guid,
      :unique_attributes    => :guid,
      :many_to_one_collection_ids => {
        :default_space => lambda { |user|
          org = user.organizations.first || Models::Organization.make
          Models::Space.make(:organization => org)
        }
      },
      :many_to_many_collection_ids => {
        :organizations => lambda { |user| Models::Organization.make },
        :managed_organizations => lambda { |user| Models::Organization.make },
        :billing_managed_organizations => lambda { |user| Models::Organization.make },
        :audited_organizations => lambda { |user| Models::Organization.make },
        :spaces    => lambda { |user|
          org = user.organizations.first || Models::Organization.make
          Models::Space.make(:organization => org)
        },
        :managed_spaces => lambda { |user|
          org = user.organizations.first || Models::Organization.make
          Models::Space.make(:organization => org)
        },
        :audited_spaces => lambda { |user|
          org = user.organizations.first || Models::Organization.make
          Models::Space.make(:organization => org)
        },
      }
    }

    include_examples "uaa authenticated api", path: "/v2/users"
    include_examples "enumerating objects", path: "/v2/users", model: Models::User
    include_examples "reading a valid object", path: "/v2/users", model: Models::User, basic_attributes: []
    include_examples "operations on an invalid object", path: "/v2/users"
  end
end
