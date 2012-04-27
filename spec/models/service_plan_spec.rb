# Copyright (c) 2009-2012 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::Models::ServicePlan do
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
