# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::AppSpace do
  # FIXME: do this via path?
  let(:org)       { VCAP::CloudController::Models::Organization.make }
  let(:app_space) { VCAP::CloudController::Models::AppSpace.make }

  it_behaves_like "a CloudController API", {
    :path                => "/v2/app_spaces",
    :model               => VCAP::CloudController::Models::AppSpace,
    :basic_attributes    => [:name, :organization_id],
    :required_attributes => [:name, :organization_id],
    :unique_attributes   => [:name, :organization_id],
    :many_to_many_collection_ids => {
      :users => lambda { |app_space| make_user_for_app_space(app_space) }
    },
    :one_to_many_collection_ids => {
      :apps  => lambda { |app_space| VCAP::CloudController::Models::App.make }
    }
  }

end
