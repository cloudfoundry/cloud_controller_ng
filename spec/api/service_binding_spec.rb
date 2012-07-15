# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::ServiceBinding do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/service_bindings",
    :model                => VCAP::CloudController::Models::ServiceBinding,
    :basic_attributes     => [:credentials, :binding_options, :vendor_data, :app_guid, :service_instance_guid],
    :required_attributes  => [:credentials, :app_guid, :service_instance_guid],
    :unique_attributes    => [:app_guid, :service_instance_guid],
    :create_attribute     => lambda { |name|
      @app_space ||= VCAP::CloudController::Models::AppSpace.make
      case name.to_sym
      when :app_guid
        app = VCAP::CloudController::Models::App.make(:app_space => @app_space)
        app.guid
      when :service_instance_guid
        service_instance = VCAP::CloudController::Models::ServiceInstance.make(:app_space => @app_space)
        service_instance.guid
      end
    },
    :create_attribute_reset => lambda { @app_space = nil }
  }

end
