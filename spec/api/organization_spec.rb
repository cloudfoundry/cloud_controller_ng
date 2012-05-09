# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::Organization do
  let(:org)   { VCAP::CloudController::Models::Organization.make }

  it_behaves_like "a CloudController API", {
    :path                => '/v2/organizations',
    :model               => VCAP::CloudController::Models::Organization,
    :basic_attributes    => :name,
    :required_attributes => :name,
    :unique_attributes   => :name,
    :many_to_many_collection_ids => {
      :users => lambda { |org| VCAP::CloudController::Models::User.make }
    },
    :one_to_many_collection_ids  => {
      :app_spaces => lambda { |org| VCAP::CloudController::Models::AppSpace.make }
    }
  }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::Organization,
    [
      ['/v2/organizations', :post, 201, 403, 401, { :name => Sham.name }],
      ['/v2/organizations', :get, 200, 403, 401],
      ['/v2/organizations/#{org.id}', :put, 201, 403, 401, { :name => '#{org.name}_renamed' }],
      ['/v2/organizations/#{org.id}', :delete, 204, 403, 401],
    ]

end
