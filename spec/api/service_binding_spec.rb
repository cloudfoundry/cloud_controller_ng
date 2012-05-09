# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::ServiceBinding do
  let(:service_binding) { VCAP::CloudController::Models::ServiceBinding.make }
  let(:app_obj) { VCAP::CloudController::Models::App.make }

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/service_bindings",
    :model                => VCAP::CloudController::Models::ServiceBinding,
    :basic_attributes     => [:credentials, :binding_options, :vendor_data, :app_id, :service_instance_id],
    :required_attributes  => [:credentials, :app_id, :service_instance_id],
    :unique_attributes    => [:app_id, :service_instance_id]
  }

end
