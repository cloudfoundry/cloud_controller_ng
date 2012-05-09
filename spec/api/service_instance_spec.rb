# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::ServiceInstance do
  let(:app_space) { VCAP::CloudController::Models::AppSpace.make }
  let(:service_plan) { VCAP::CloudController::Models::ServicePlan.make }
  let(:service_instance) { VCAP::CloudController::Models::ServiceInstance.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/service_instances',
    :model                => VCAP::CloudController::Models::ServiceInstance,
    :basic_attributes     => [:name, :credentials, :vendor_data],
    :required_attributes  => [:name, :credentials, :app_space_id, :service_plan_id],
    :unique_attributes    => [:app_space_id, :name],
    :one_to_many_collection_ids => {
      :service_bindings => lambda { |service_instance|
        make_service_binding_for_service_instance(service_instance)
      }
    }
  }

end
