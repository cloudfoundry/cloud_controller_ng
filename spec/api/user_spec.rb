# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::User do
  let(:user) { u = VCAP::CloudController::Models::User.make }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::User,
    [
      ['/v2/users', :post, 201, 403, 401, { :name => Sham.name, :id => Sham.uaa_id }],
      ['/v2/users', :get, 200, 403, 401],
      # FIXME: Changing the id is not allowd.  This currently returns a server
      # error because sequel gets really confused when you try to do this as it
      # tries to do an update users set id = 'new_id' where id = 'new_id' which
      # rather than where id = 'old_id'.  In any case, a user's uaa id won't
      # change, so add the correct test here and return a proper error.
      #
      # ['/v2/users/#{user.id}', :put, 201, 403, 401, { :id => '#{user.id}_changed' }],
      ['/v2/users/#{user.id}', :delete, 204, 403, 401],
    ]

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/users',
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
