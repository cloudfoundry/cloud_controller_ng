# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe ServiceInstance do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/service_instances",
    :model                => VCAP::CloudController::Models::ServiceInstance,
    :basic_attributes     => [:name, :credentials, :vendor_data],
    :required_attributes  => [:name, :credentials, :app_space_guid, :service_plan_guid],
    :unique_attributes    => [:app_space_guid, :name],
    :one_to_many_collection_ids => {
      :service_bindings => lambda { |service_instance|
        make_service_binding_for_service_instance(service_instance)
      }
    }
  }

end
end
