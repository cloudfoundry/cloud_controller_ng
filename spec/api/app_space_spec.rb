# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::AppSpace do
  # FIXME: do this via path?
  let(:org)       { VCAP::CloudController::Models::Organization.make }
  let(:app_space) { VCAP::CloudController::Models::AppSpace.make }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::AppSpace,
    [
      ['/v2/app_spaces', :post, 201, 403, 401, { :name => Sham.name, :organization_id => '#{org.id}' }],
      ['/v2/app_spaces', :get, 200, 403, 401],
      ['/v2/app_spaces/#{app_space.id}', :put, 201, 403, 401, { :name => '#{app_space.name}_renamed' }],
      ['/v2/app_spaces/#{app_space.id}', :delete, 204, 403, 401],
    ]

  it_behaves_like "a CloudController API", {
    :path                => '/v2/app_spaces',
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
