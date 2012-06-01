# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::User do
  let(:user) { u = VCAP::CloudController::Models::User.make }

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/users",
    :model                => VCAP::CloudController::Models::User,
    :basic_attributes     => :id,
    :required_attributes  => :id,
    :unique_attributes    => :id,
    :many_to_many_collection_ids => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :app_spaces    => lambda { |user|
         org = user.organizations.first || VCAP::CloudController::Models::Organization.make
         VCAP::CloudController::Models::AppSpace.make(:organization => org)
      }
    }
  }

end
