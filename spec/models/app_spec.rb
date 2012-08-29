# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::App do
  let(:org) { Models::Organization.make }
  let(:space) { Models::Space.make(:organization => org) }
  let(:domain) do
    d = Models::Domain.make(:owning_organization => org)
    org.add_domain(d)
    space.add_domain(d)
    d
  end
  let(:route) { Models::Route.make(:domain => domain, :organization => org) }

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
         domain = VCAP::CloudController::Models::Domain.make(
           :owning_organization => app.space.organization)
           route = VCAP::CloudController::Models::Route.make(
             :domain => domain,
             :organization => app.space.organization)
         app.space.add_domain(route.domain)
         route
       }
    }
  }

  describe "bad relationships" do
    it "should not associate an app with a route using a domain not approved for the app space" do
      app = Models::App.make
      domain = Models::Domain.make(:owning_organization => app.space.organization)
      route = VCAP::CloudController::Models::Route.make(
        :organization => app.space.organization,
        :domain => domain
      )

      lambda {
        app.add_route(route)
      }.should raise_error Models::App::InvalidRouteRelation
    end

    it "should not associate an app with a route created by another org with a shared domain" do
      shared_domain = Models::Domain.new(:name => Sham.name,
                                         :owning_organization => nil)
      shared_domain.save(:validate => false)
      app = Models::App.make
      app.space.add_domain(shared_domain)

      other_org = Models::Organization.make
      route = VCAP::CloudController::Models::Route.make(
        :organization => other_org,
        :domain => shared_domain
      )

      lambda {
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
      app.package_hash.should == "def"
    end

    it "should not set the state to PENDING if the hash remains the same" do
      app.package_hash = "abc"
      app.package_state.should == "STAGED"
      app.package_hash.should == "abc"
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

  describe "started?" do
    let(:app) { Models::App.make }

    it "should return true if app is STARTED" do
      app.state = "STARTED"
      app.started?.should be_true
    end

    it "should return false if app is STOPPED" do
      app.state = "STOPPED"
      app.started?.should be_false
    end
  end

  describe "stopped?" do
    let(:app) { Models::App.make }

    it "should return true if app is STOPPED" do
      app.state = "STOPPED"
      app.stopped?.should be_true
    end

    it "should return false if app is STARTED" do
      app.state = "STARTED"
      app.stopped?.should be_false
    end
  end

  describe "version" do
    let(:app) { Models::App.make }

    it "should have a version on create" do
      app.version.should_not be_nil
    end

    it "should not update the version when changing :memory" do
      orig_version = app.version
      app.memory = 1024
      app.save
      app.version.should == orig_version
    end

    it "should update the version when changing :state" do
      orig_version = app.version
      app.state = "STARTED"
      app.save
      app.version.should_not == orig_version
    end

    it "should not update the version if the caller set it" do
      app.version = "my-version"
      app.state = "STARTED"
      app.save
      app.version.should == "my-version"
    end

    it "should not update the version on update of :memory" do
      orig_version = app.version
      app.update(:memory => 999)
      app.version.should == orig_version
    end

    it "should update the version on update of :state" do
      orig_version = app.version
      app.update(:state => "STARTED")
      app.version.should_not == orig_version
    end
  end

  describe "droplet_hash=" do
    let(:app) { Models::App.make }

    it "should set the state to staged" do
      app.package_hash = "abc"
      app.needs_staging?.should be_true
      app.droplet_hash = "def"
      app.needs_staging?.should be_false
      app.droplet_hash.should == "def"
    end
  end

  describe "uris" do
    it "should return the uris on the app" do
      app = Models::App.make(:space => space)
      app.add_route(route)
      app.uris.should == [route.fqdn]
    end
  end

  describe "adding routes to unsaved apps" do
    it "should set a route by guid on a new but unsaved app" do
      app = Models::App.new(:name => Sham.name,
                            :framework => Models::Framework.make,
                            :runtime => Models::Runtime.make,
                            :space => space)
      app.add_route_by_guid(route.guid)
      app.save
      app.routes.should == [route]
    end

    it "should not allow a route on a domain from another org" do
      app = Models::App.new(:name => Sham.name,
                            :framework => Models::Framework.make,
                            :runtime => Models::Runtime.make,
                            :space => space)
      app.add_route_by_guid(Models::Route.make.guid)
      expect { app.save }.should raise_error(Models::App::InvalidRouteRelation)
      app.routes.should be_empty
    end
  end
end
