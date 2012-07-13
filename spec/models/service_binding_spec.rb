# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::ServiceBinding do
  it_behaves_like "a CloudController model", {
    :required_attributes => [:credentials, :service_instance, :app],
    :unique_attributes   => [:app, :service_instance],
    :create_attribute    => lambda { |name|
      @app_space ||= VCAP::CloudController::Models::AppSpace.make
      case name
      when :app
        app = VCAP::CloudController::Models::App.make
        app.app_space = @app_space
        return app
      when :service_instance
        service_instance = VCAP::CloudController::Models::ServiceInstance.make
        service_instance.app_space = @app_space
        return service_instance
      end
    },
    :many_to_one => {
      :app => {
        :delete_ok => true,
        :create_for => lambda { |service_binding|
          VCAP::CloudController::Models::App.make(:app_space => service_binding.app_space)
        }
      },
      :service_instance => lambda { |service_binding|
        VCAP::CloudController::Models::ServiceInstance.make(:app_space => service_binding.app_space)
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
      }.should raise_error Models::ServiceBinding::InvalidAppAndServiceRelation
    end

    it "should not associate a service with an app from a different app space" do
      lambda {
        service_binding = VCAP::CloudController::Models::ServiceBinding.make
        service_binding.service_instance = @service_instance
      }.should raise_error Models::ServiceBinding::InvalidAppAndServiceRelation
    end
  end
end
