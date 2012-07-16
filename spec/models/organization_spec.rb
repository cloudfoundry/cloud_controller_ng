# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::Organization do
  it_behaves_like "a CloudController model", {
    :required_attributes          => :name,
    :unique_attributes            => :name,
    :stripped_string_attributes   => :name,
    :many_to_zero_or_more => {
      :users      => lambda { |org| VCAP::CloudController::Models::User.make },
      :managers   => lambda { |org| VCAP::CloudController::Models::User.make },
      :billing_managers => lambda { |org| VCAP::CloudController::Models::User.make },
      :auditors   => lambda { |org| VCAP::CloudController::Models::User.make },
    },
    :one_to_zero_or_more => {
      :spaces  => lambda { |org| VCAP::CloudController::Models::Space.make },
      :domains => lambda { |org| VCAP::CloudController::Models::Domain.make }
    }
  }
end
