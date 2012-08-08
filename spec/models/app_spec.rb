# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::App do
  it_behaves_like "a CloudController model", {
    :required_attributes  => [:name, :framework, :runtime, :space],
    :unique_attributes    => [:space, :name],
    :stripped_string_attributes => :name,
    :many_to_one => {
      :space              => lambda { |app| VCAP::CloudController::Models::Space.make  },
      :framework          => lambda { |app| VCAP::CloudController::Models::Framework.make },
      :runtime            => lambda { |app| VCAP::CloudController::Models::Runtime.make   }
    },
    :one_to_zero_or_more  => {
      :service_bindings   => lambda { |app|
          service_binding = VCAP::CloudController::Models::ServiceBinding.make
          service_binding.service_instance.space = app.space
          service_binding
       },
       :routes => lambda { |app|
         route = VCAP::CloudController::Models::Route.make
         app.space.organization.add_domain(route.domain)
         app.space.add_domain(route.domain)
         route
       }
    }
  }

  describe "bad relationships" do
    let(:app) { Models::App.make }

    it "should not associate an app with a route using a domain not approved for the app space" do
      lambda {
        route = VCAP::CloudController::Models::Route.make
        app.add_route(route)
      }.should raise_error Models::App::InvalidRouteRelation
    end
  end

  describe "validations" do
    describe "env" do
      let(:app) { Models::App.make }

      it "should allow an empty environment" do
        app.environment_json = {}
        app.should be_valid
      end

      it "should allow multiple variables" do
        app.environment_json = { :abc => 123, :def => "hi" }
        app.should be_valid
      end

      [ "VMC", "vmc", "VCAP", "vcap" ].each do |k|
        it "should not allow entries to start with #{k}" do
          app.environment_json = { :abc => 123, "#{k}_abc" => "hi" }
          app.should_not be_valid
        end
      end
    end
  end

  describe "package_hash=" do
    let(:app) { Models::App.make }

    before do
      app.package_hash = "abc"
      app.package_state = "STAGED"
    end

    it "should set the state to PENDING if the hash changes" do
      app.package_hash = "def"
      app.package_state.should == "PENDING"
    end

    it "should not set the state to PENDING if the hash remains the same" do
      app.package_hash = "abc"
      app.package_state.should == "STAGED"
    end
  end

  describe "staged?" do
    let(:app) { Models::App.make }

    it "should return true if package_state is STAGED" do
      app.package_state = "STAGED"
      app.staged?.should be_true
    end

    it "should return false if package_state is PENDING" do
      app.package_state = "PENDING"
      app.staged?.should be_false
    end
  end

  describe "needs_staging?" do
    let(:app) { Models::App.make }

    it "should return false if the package_hash is nil" do
      app.package_hash.should be_nil
      app.needs_staging?.should be_false
    end

    it "should return true if PENDING is set" do
      app.package_hash = "abc"
      app.package_state = "PENDING"
      app.needs_staging?.should be_true
    end

    it "should return false if STAGING is set" do
      app.package_hash = "abc"
      app.package_state = "STAGED"
      app.needs_staging?.should be_false
    end
  end
end
