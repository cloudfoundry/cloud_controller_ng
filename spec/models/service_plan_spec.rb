# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Models::ServicePlan do
  it_behaves_like "a CloudController model", {
    :required_attributes => [:name, :description, :service],
    :unique_attributes   => [:service, :name],
    :stripped_string_attributes => :name,
    :many_to_one => {
      :service   => lambda { |service_plan| VCAP::CloudController::Models::Service.make }
    },
    :one_to_zero_or_more  => {
      :service_instances => lambda { |service_plan| VCAP::CloudController::Models::ServiceInstance.make }
    },
  }
end
end
