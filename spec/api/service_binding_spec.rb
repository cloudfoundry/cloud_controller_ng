# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe ServiceBinding do

  # TODO: reenable
  #
  # it_behaves_like "a CloudController API", {
  #   :path                 => "/v2/service_bindings",
  #   :model                => VCAP::CloudController::Models::ServiceBinding,
  #   :basic_attributes     => [:credentials, :binding_options, :vendor_data, :app_guid, :service_instance_guid],
  #   :required_attributes  => [:credentials, :app_guid, :service_instance_guid],
  #   :unique_attributes    => [:app_guid, :service_instance_guid]
  # }

end
end
