# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::ServicePlan do
  let(:service_plan) { VCAP::CloudController::Models::ServicePlan.make }
  let(:service) { VCAP::CloudController::Models::Service.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/service_plans',
    :model                => VCAP::CloudController::Models::ServicePlan,
    :basic_attributes     => [:name, :description, :service_id],
    :required_attributes  => [:name, :description, :service_id],
    :unique_attributes    => [:name, :service_id],
    :one_to_many_collection_ids  => {
      :service_instances => lambda { |service_plan| VCAP::CloudController::Models::ServiceInstance.make }
    }
  }

end
