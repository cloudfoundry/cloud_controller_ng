# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::ServiceBinding do
  it_behaves_like "a CloudController model", {
    :required_attributes => [:credentials, :service_instance, :app],
    :unique_attributes   => [:app, :service_instance],
    :create_attribute    => lambda { |name|
      @space ||= VCAP::CloudController::Models::Space.make
      case name.to_sym
      when :app_id
        app = VCAP::CloudController::Models::App.make(:space => @space)
        app.id
      when :service_instance_id
        service_instance = VCAP::CloudController::Models::ServiceInstance.make(:space => @space)
        service_instance.id
      end
    },
    :create_attribute_reset => lambda { @space = nil },
    :many_to_one => {
      :app => {
        :delete_ok => true,
        :create_for => lambda { |service_binding|
          VCAP::CloudController::Models::App.make(:space => service_binding.space)
        }
      },
      :service_instance => lambda { |service_binding|
        VCAP::CloudController::Models::ServiceInstance.make(:space => service_binding.space)
      }
    }
  }

  describe "bad relationships" do
    before do
      # since we don't set them, these will have different app spaces
      @service_instance = VCAP::CloudController::Models::ServiceInstance.make
      @app = VCAP::CloudController::Models::App.make
      @service_binding = VCAP::CloudController::Models::ServiceBinding.make
    end

    it "should not associate an app with a service from a different app space" do
      lambda {
        service_binding = VCAP::CloudController::Models::ServiceBinding.make
        service_binding.app = @app
        service_binding.save
      }.should raise_error Models::ServiceBinding::InvalidAppAndServiceRelation
    end

    it "should not associate a service with an app from a different app space" do
      lambda {
        service_binding = VCAP::CloudController::Models::ServiceBinding.make
        service_binding.service_instance = @service_instance
        service_binding.save
      }.should raise_error Models::ServiceBinding::InvalidAppAndServiceRelation
    end
  end
end
