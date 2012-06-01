# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::AppSpace do

  it_behaves_like "a CloudController API", {
    :path                => '/v2/app_spaces',
    :model               => VCAP::CloudController::Models::AppSpace,
    :basic_attributes    => [:name, :organization_guid],
    :required_attributes => [:name, :organization_guid],
    :unique_attributes   => [:name, :organization_guid],
    :many_to_many_collection_ids => {
      :users => lambda { |app_space| make_user_for_app_space(app_space) }
    },
    :one_to_many_collection_ids => {
      :apps  => lambda { |app_space| VCAP::CloudController::Models::App.make }
    }
  }

end
