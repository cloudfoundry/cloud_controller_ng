# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::ServiceBinding do

  # TODO: reenable
  #
  # it_behaves_like "a CloudController API", {
  #   :path                 => '/v2/service_bindings',
  #   :model                => VCAP::CloudController::Models::ServiceBinding,
  #   :basic_attributes     => [:credentials, :binding_options, :vendor_data, :app_guid, :service_instance_guid],
  #   :required_attributes  => [:credentials, :app_guid, :service_instance_guid],
  #   :unique_attributes    => [:app_guid, :service_instance_guid]
  # }

end
