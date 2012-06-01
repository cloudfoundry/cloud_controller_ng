# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::ServicePlan do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/service_plans",
    :model                => VCAP::CloudController::Models::ServicePlan,
    :basic_attributes     => [:name, :description, :service_guid],
    :required_attributes  => [:name, :description, :service_guid],
    :unique_attributes    => [:name, :service_guid],
    :one_to_many_collection_ids  => {
      :service_instances => lambda { |service_plan| VCAP::CloudController::Models::ServiceInstance.make }
    }
  }

end
