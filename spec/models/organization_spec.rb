# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Models::Organization do

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
      :app_spaces => lambda { |org| VCAP::CloudController::Models::AppSpace.make }
    }
  }
end
end
