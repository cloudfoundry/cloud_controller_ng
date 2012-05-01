# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::User do
  let(:user) { VCAP::CloudController::Models::User.make }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::User,
    [
      ['/v2/users', :post, 201, 403, 401, { :name => Sham.name, :email => Sham.email, :password => Sham.password }],
      ['/v2/users', :get, 200, 403, 401],
      ['/v2/users/#{user.id}', :put, 201, 403, 401, { :email => '#{user.email}_changed' }],
      ['/v2/users/#{user.id}', :delete, 204, 403, 401],
    ]

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/users',
    :model                => VCAP::CloudController::Models::User,
    :basic_attributes     => :email,
    :required_attributes  => [:email, :password],
    :unique_attributes    => :email,
    :extra_attributes     => :password,
    :sensitive_attributes => :password,
    :many_to_many_collection_ids => {
      :organizations => lambda { |user| VCAP::CloudController::Models::Organization.make },
      :app_spaces    => lambda { |user|
         org = VCAP::CloudController::Models::Organization.make
         user.add_organization(org)
         VCAP::CloudController::Models::AppSpace.make(:organization => org)
      }
    }
  }

end
