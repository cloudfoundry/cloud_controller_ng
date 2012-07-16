# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::ServiceInstance do
  it_behaves_like "a CloudController model", {
    :required_attributes => [:name, :credentials, :service_plan, :space],
    :unique_attributes   => [:space, :name],
    :stripped_string_attributes => :name,
    :many_to_one         => {
      :service_plan      => lambda { |service_instance| VCAP::CloudController::Models::ServicePlan.make },
      :space             => lambda { |service_instance| VCAP::CloudController::Models::Space.make },
    },
    :one_to_zero_or_more => {
      :service_bindings  => lambda { |service_instance|
        make_service_binding_for_service_instance(service_instance)
      }
    }
  }

  context "bad relationships" do
    let(:service_instance) { Models::ServiceInstance.make }

    context "service binding" do
      it "should not bind an app and a service instance from different app spaces" do
        app = VCAP::CloudController::Models::App.make(:space => service_instance.space)
        service_binding = VCAP::CloudController::Models::ServiceBinding.make
        lambda {
          service_instance.add_service_binding(service_binding)
        }.should raise_error Models::ServiceInstance::InvalidServiceBinding
      end
    end
  end
end
