# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Models::App do
    let(:org) { Models::Organization.make }
    let(:space) { Models::Space.make(:organization => org) }
    let(:domain) do
      d = Models::Domain.make(:owning_organization => org)
      org.add_domain(d)
      space.add_domain(d)
      d
    end
    let(:route) { Models::Route.make(:domain => domain, :space => space) }

    it_behaves_like "a CloudController model", {
      :required_attributes  => [:name, :framework, :runtime, :space],
      :unique_attributes    => [:space, :name],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :space              => lambda { |app| Models::Space.make  },
        :framework          => lambda { |app| Models::Framework.make },
        :runtime            => lambda { |app| Models::Runtime.make   }
      },
      :one_to_zero_or_more  => {
        :service_bindings   => lambda { |app|
          service_binding = Models::ServiceBinding.make
          service_binding.service_instance.space = app.space
          service_binding
        },
        :routes => lambda { |app|
          domain = Models::Domain.make(
            :owning_organization => app.space.organization
          )
          app.space.add_domain(domain)
          Models::Route.make(
            :domain => domain,
            :space => app.space
          )
        }
      }
    }

    describe "bad relationships" do
      it "should not associate an app with a route on a different space" do
        app = Models::App.make

        domain = Models::Domain.make(
          :owning_organization => app.space.organization
        )

        other_space = Models::Space.make(:organization => app.space.organization)
        other_space.add_domain(domain)

        route = Models::Route.make(
          :space => other_space,
          :domain => domain,
        )

        lambda {
          app.add_route(route)
        }.should raise_error Models::App::InvalidRouteRelation
      end

      it "should not associate an app with a route created on another space with a shared domain" do
        shared_domain = Models::Domain.new(:name => Sham.name,
                                           :owning_organization => nil)
        shared_domain.save(:validate => false)
        app = Models::App.make
        app.space.add_domain(shared_domain)

        other_space = Models::Space.make(:organization => app.space.organization)
        route = Models::Route.make(
          :host => Sham.host,
          :space => other_space,
          :domain => shared_domain
        )

        lambda {
          app.add_route(route)
        }.should raise_error Models::App::InvalidRouteRelation
      end
    end

    describe "#environment_json" do
      it "deserializes the serialized value" do
        app = Models::App.make(
          :environment_json => { "jesse" => "awesome" },
        )
        app.environment_json.should eq("jesse" => "awesome")
      end

      it "marks an app for restage if env changed from none to containing BUNDLE_WITHOUT" do
        app = Models::App.make
        app.package_hash = "deadbeef"
        app.update(:package_state => "STAGED")

        app.needs_staging?.should be_false
        app.environment_json = {"BUNDLE_WITHOUT" => "test"}
        app.save
        app.needs_staging?.should be_true
      end

      it "marks an app for restage if BUNDLE_WITHOUT is added to env" do
        app = Models::App.make(
          :environment_json => {"jesse" => "awesome"},
        )
        app.package_hash = "deadbeef"
        app.update(:package_state => "STAGED")

        app.needs_staging?.should be_false
        # NB we cannot use Hash#merge!
        app.environment_json = app.environment_json.merge("BUNDLE_WITHOUT" => "test")
        app.save
        app.needs_staging?.should be_true
      end

      it "marks an app for restage if BUNDLE_WITHOUT is removed from env" do
        app = Models::App.make(
          :environment_json => {
            "BUNDLE_WITHOUT" => "test",
            "foo" => "bar",
          },
        )
        app.package_hash = "deadbeef"
        app.update(:package_state => "STAGED")

        app.needs_staging?.should be_false
        app.environment_json = {"foo" => "bar"}
        app.save
        app.needs_staging?.should be_true
      end

      it "marks an app for restage if value of BUNDLE_WITHOUT changed in env" do
        app = Models::App.make(
          :environment_json => {
            "BUNDLE_WITHOUT" => "test",
            "foo" => "bar",
          },
        )
        app.package_hash = "deadbeef"
        app.update(:package_state => "STAGED")

        app.needs_staging?.should be_false
        app.environment_json = {"foo" => "bar", "BUNDLE_WITHOUT" => "development"}
        app.save
        app.needs_staging?.should be_true
      end
    end

    describe "metadata" do
      it "deserializes the serialized value" do
        app = Models::App.make(
          :metadata => { "jesse" => "super awesome" },
        )
        app.metadata.should eq("jesse" => "super awesome")
      end
    end

    describe "command" do
      it "stores the command in the metadata" do
        app = Models::App.make(:command => "foobar")
        app.metadata.should eq("command" => "foobar")
        app.save
        app.metadata.should eq("command" => "foobar")
        app.refresh
        app.metadata.should eq("command" => "foobar")
      end
    end

    describe "console" do
      it "stores the command in the metadata" do
        app = Models::App.make(:console => true)
        app.metadata.should eq("console" => true)
        app.save
        app.metadata.should eq("console" => true)
        app.refresh
        app.metadata.should eq("console" => true)
      end

      it "returns false if console was explicitly set to false" do
        app = Models::App.make(:console => false)
        app.console.should == false
      end

      it "returns false if console was not set" do
        app = Models::App.make(:console => true)
        app.console.should == true
      end
    end

    describe "validations" do
      describe "env" do
        let(:app) { Models::App.make }

        it "should allow an empty environment" do
          app.environment_json = {}
          app.should be_valid
        end

        it "should not allow an array" do
          app.environment_json = []
          app.should_not be_valid
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

      describe "metadata" do
        let(:app) { Models::App.make }

        it "should allow empty metadata" do
          app.metadata = {}
          app.should be_valid
        end

        it "should not allow an array" do
          app.metadata = []
          app.should_not be_valid
        end

        it "should allow multiple variables" do
          app.metadata = { :abc => 123, :def => "hi" }
          app.should be_valid
        end

        it "should save direct updates to the metadata" do
          app.metadata.should == {}
          app.metadata["some_key"] = "some val"
          app.metadata["some_key"].should == "some val"
          app.save
          app.metadata["some_key"].should == "some val"
          app.refresh
          app.metadata["some_key"].should == "some val"
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

    describe "destroy" do
      let(:app) { Models::App.make }

      context "with a started app" do
        it "should stop the app on the dea" do
          app.state = "STARTED"
          app.save
          DeaClient.should_receive(:stop).with(app)
          app.destroy
        end
      end

      context "with a stopped app" do
        it "should not stop the app on the dea" do
          app.state = "STOPPED"
          app.save
          DeaClient.should_not_receive(:stop)
          app.destroy
        end
      end

      it "should remove the droplet" do
        AppStager.should_receive(:delete_droplet).with(app)
        app.destroy
      end

      it "should remove the package" do
        AppPackage.should_receive(:delete_package).with(app.guid)
        app.destroy
      end
    end

    describe "billing" do
      context "app state changes" do
        context "creating a stopped app" do
          it "should not call AppStartEvent.create_from_app" do
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            Models::App.make(:state => "STOPPED")
          end
        end

        context "creating a started app" do
          it "should not call AppStopEvent.create_from_app" do
            Models::AppStartEvent.should_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            Models::App.make(:state => "STARTED")
          end
        end

        context "starting a stopped app" do
          it "should call AppStartEvent.create_from_app" do
            app = Models::App.make(:state => "STOPPED")
            Models::AppStartEvent.should_receive(:create_from_app).with(app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STARTED")
          end
        end

        context "updating a stopped app" do
          it "should not call AppStartEvent.create_from_app" do
            app = Models::App.make(:state => "STOPPED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STOPPED")
          end
        end

        context "stopping a started app" do
          it "should call AppStopEvent.create_from_app" do
            app = Models::App.make(:state => "STARTED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_receive(:create_from_app).with(app)
            app.update(:state => "STOPPED")
          end
        end

        context "updating a started app" do
          it "should not call AppStartEvent.create_from_app" do
            app = Models::App.make(:state => "STARTED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STARTED")
          end
        end

        context "deleting a started app" do
          it "should call AppStopEvent.create_from_app" do
            app = Models::App.make(:state => "STARTED")
            VCAP::CloudController::DeaClient.stub(:stop)
            Models::AppStopEvent.should_receive(:create_from_app).with(app)
            app.destroy
          end
        end

        context "deleting a stopped app" do
          it "should not call AppStopEvent.create_from_app" do
            app = Models::App.make(:state => "STOPPED")
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.destroy
          end
        end
      end

      context "footprint changes" do
        context "new app" do
          it "should not call AppStartEvent.create_from_app or AppStopEvent.create_from_app" do
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app = Models::App.make(:state => "STOPPED", :memory => 512)
          end
        end

        context "no change in footprint" do
          it "should not call AppStartEvent.create_from_app or AppStopEvent.create_from_app" do
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app = Models::App.make
            app.save
          end
        end

        context "change in memory" do
          it "should call AppStopEvent.create_from_app and AppStartEvent.create_from_app" do
            Models::AppStopEvent.should_receive(:create_from_app).once
            Models::AppStartEvent.should_receive(:create_from_app).twice
            app = Models::App.make(:state => "STARTED")
            app.memory = 512
            app.save
          end
        end

        context "change in production flag" do
          it "should call AppStopEvent.create_from_app and AppStartEvent.create_from_app" do
            Models::AppStopEvent.should_receive(:create_from_app).once
            Models::AppStartEvent.should_receive(:create_from_app).twice
            app = Models::App.make(:state => "STARTED")
            app.production = true
            app.save
          end
        end

        context "change in instances" do
          it "should call AppStopEvent.create_from_app and AppStartEvent.create_from_app" do
            Models::AppStopEvent.should_receive(:create_from_app).once
            Models::AppStartEvent.should_receive(:create_from_app).twice
            app = Models::App.make(:state => "STARTED")
            app.instances = 5
            app.save
          end
        end
      end
    end

    describe "quota" do
      let(:paid_quota) do
        Models::QuotaDefinition.make(:paid_memory_limit => 128)
      end

      let(:free_quota) do
        Models::QuotaDefinition.make(:free_memory_limit => 128)
      end

      context "paid quota" do
        context "app creation" do
          it "should raise error when quota is exceeded" do
            org = Models::Organization.make(:quota_definition => paid_quota)
            space = Models::Space.make(:organization => org)
            expect  do
              Models::App.make(:space => space,
                               :production => true,
                               :memory => 65,
                               :instances => 2)
            end.to raise_error(Sequel::ValidationFailed,
                               /memory paid_quota_exceeded/)
          end

          it "should not raise error when quota is not exceeded" do
            org = Models::Organization.make(:quota_definition => paid_quota)
            space = Models::Space.make(:organization => org)
            expect  do
              Models::App.make(:space => space,
                               :production => true,
                               :memory => 64,
                               :instances => 2)
            end.to_not raise_error
          end
        end

        context "app update" do
          it "should raise error when quota is exceeded" do
            org = Models::Organization.make(:quota_definition => paid_quota)
            space = Models::Space.make(:organization => org)
            app = Models::App.make(:space => space,
                                   :production => true,
                                   :memory => 64,
                                   :instances => 2)
            app.memory = 65
            expect { app.save }.to raise_error(Sequel::ValidationFailed,
                                               /memory paid_quota_exceeded/)
          end

          it "should not raise error when quota is not exceeded" do
            org = Models::Organization.make(:quota_definition => paid_quota)
            space = Models::Space.make(:organization => org)
            app = Models::App.make(:space => space,
                                   :production => true,
                                   :memory => 63,
                                   :instances => 2)
            app.memory = 64
            expect { app.save }.to_not raise_error
          end
        end
      end

      context "free quota" do
        context "app creation" do
          it "should raise error when quota is exceeded" do
            org = Models::Organization.make(:quota_definition => free_quota)
            space = Models::Space.make(:organization => org)
            expect  do
              Models::App.make(:space => space,
                               :memory => 65,
                               :instances => 2)
            end.to raise_error(Sequel::ValidationFailed,
                               /memory free_quota_exceeded/)
          end

          it "should not raise error when quota is not exceeded" do
            org = Models::Organization.make(:quota_definition => free_quota)
            space = Models::Space.make(:organization => org)
            expect  do
              Models::App.make(:space => space,
                               :memory => 64,
                               :instances => 2)
            end.to_not raise_error
          end
        end

        context "app update" do
          it "should raise error when quota is exceeded" do
            org = Models::Organization.make(:quota_definition => free_quota)
            space = Models::Space.make(:organization => org)
            app = Models::App.make(:space => space,
                                   :memory => 64,
                                   :instances => 2)
            app.memory = 65
            expect { app.save }.to raise_error(Sequel::ValidationFailed,
                                               /memory free_quota_exceeded/)
          end

          it "should not raise error when quota is not exceeded" do
            org = Models::Organization.make(:quota_definition => free_quota)
            space = Models::Space.make(:organization => org)
            app = Models::App.make(:space => space,
                                   :memory => 63,
                                   :instances => 2)
            app.memory = 64
            expect { app.save }.to_not raise_error
          end
        end
      end
    end

    describe "file_descriptors" do
      subject { Models::App.make }
      its(:file_descriptors) { should == 16_384 }
    end
  end
end
