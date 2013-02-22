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
      :required_attributes => [:name, :framework, :runtime, :space],
      :unique_attributes => [:space, :name],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :space => lambda { |app| Models::Space.make },
        :framework => lambda { |app| Models::Framework.make },
        :runtime => lambda { |app| Models::Runtime.make }
      },
      :one_to_zero_or_more => {
        :service_bindings => lambda { |app|
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

        expect {
          app.add_route(route)
        }.to raise_error Models::App::InvalidRouteRelation
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

        expect {
          app.add_route(route)
        }.to raise_error Models::App::InvalidRouteRelation
      end
    end

    describe "#environment_json" do
      it "deserializes the serialized value" do
        app = Models::App.make(
          :environment_json => { "jesse" => "awesome" },
        )
        app.environment_json.should eq("jesse" => "awesome")
      end

      shared_examples "env change doesn't mark an app for restage" do
        let(:old_env_json) { }

        it "does not mark an app for restage" do
          app = Models::App.make(
            :package_hash => "deadbeef",
            :package_state => "STAGED",
            :environment_json => old_env_json,
          )
          app.needs_staging?.should be_false

          app.environment_json = new_env_json
          app.save
          app.needs_staging?.should be_false
        end
      end

      context "if env changes" do
        let(:new_env_json) { { "key" => "value" } }
        it_behaves_like "env change doesn't mark an app for restage"
      end

      context "if BUNDLE_WITHOUT in env changes" do
        let(:old_env_json) { { "BUNDLE_WITHOUT" => "test" } }
        let(:new_env_json) { { "BUNDLE_WITHOUT" => "development" } }
        it_behaves_like "env change doesn't mark an app for restage"
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

    describe "debug" do
      it "stores the command in the metadata" do
        app = Models::App.make(:debug => "suspend")
        app.metadata.should eq("debug" => "suspend")
        app.save
        app.metadata.should eq("debug" => "suspend")
        app.refresh
        app.metadata.should eq("debug" => "suspend")
      end

      it "returns nil if debug was explicitly set to nil" do
        app = Models::App.make(:debug => nil)
        app.debug.should be_nil
      end

      it "returns nil if debug was not set" do
        app = Models::App.make
        app.debug.should be_nil
      end
    end

    describe "validations" do
      describe "env" do
        let(:app) { Models::App.make }

        it "should allow an empty environment" do
          app.environment_json = { }
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

        ["VMC", "vmc", "VCAP", "vcap"].each do |k|
          it "should not allow entries to start with #{k}" do
            app.environment_json = { :abc => 123, "#{k}_abc" => "hi" }
            app.should_not be_valid
          end
        end
      end

      describe "metadata" do
        let(:app) { Models::App.make }

        it "should allow empty metadata" do
          app.metadata = { }
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
          app.metadata.should == { }
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
      let(:app) { Models::App.make(:package_hash => "abc", :package_state => "STAGED") }

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

      it "should update the version when changing :state" do
        app.state = "STARTED"
        expect { app.save }.to change(app, :version)
      end

      it "should not update the version if the caller set it" do
        app.version = "my-version"
        app.state = "STARTED"
        app.save
        app.version.should == "my-version"
      end

      it "should update the version on update of :state" do
        expect { app.update(:state => "STARTED") }.to change(app, :version)
      end

      context "for a started app" do
        before { app.update(:state => "STARTED") }

        it "should update the version when changing :memory" do
          app.memory = 1024
          expect { app.save }.to change(app, :version)
        end

        it "should update the version on update of :memory" do
          expect { app.update(:memory => 999) }.to change(app, :version)
        end

        it "should not update the version when changing :instances" do
          app.instances = 8
          expect { app.save }.to_not change(app, :version)
        end

        it "should not update the version on update of :instances" do
          expect { app.update(:instances => 8) }.to_not change(app, :version)
        end
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
        expect { app.save }.to raise_error(Models::App::InvalidRouteRelation)
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
          it "does not generate a start event or stop event" do
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            Models::App.make(:state => "STOPPED")
          end
        end

        context "creating a started app" do
          it "does not generate a stop event" do
            Models::AppStartEvent.should_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            Models::App.make(:state => "STARTED")
          end
        end

        context "starting a stopped app" do
          it "generates a start event" do
            app = Models::App.make(:state => "STOPPED")
            Models::AppStartEvent.should_receive(:create_from_app).with(app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STARTED")
          end
        end

        context "updating a stopped app" do
          it "does not generate a start event or stop event" do
            app = Models::App.make(:state => "STOPPED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STOPPED")
          end
        end

        context "stopping a started app" do
          it "does not generate a start event, but generates a stop event" do
            app = Models::App.make(:state => "STARTED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_receive(:create_from_app).with(app)
            app.update(:state => "STOPPED")
          end
        end

        context "updating a started app" do
          it "does not generate a start or stop event" do
            app = Models::App.make(:state => "STARTED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STARTED")
          end
        end

        context "deleting a started app" do
          it "generates a start event" do
            app = Models::App.make(:state => "STARTED")
            VCAP::CloudController::DeaClient.stub(:stop)
            Models::AppStopEvent.should_receive(:create_from_app).with(app)
            app.destroy
          end
        end

        context "deleting a stopped app" do
          it "does not generate a stop event" do
            app = Models::App.make(:state => "STOPPED")
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.destroy
          end
        end
      end

      context "footprint changes" do
        let(:app) do
          app = Models::App.make
          app_org = app.space.organization
          app_org.billing_enabled = true
          app_org.save(:validate => false) # because we need to force enable billing
          app
        end

        context "new app" do
          it "does not generate a start event or stop event" do
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app
          end
        end

        context "no change in footprint" do
          it "does not generate a start event or stop event" do
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.save
          end
        end

        context "started app" do
          before do
            app.state = "STARTED"
            app.save
          end

          def self.it_emits_app_start_and_stop_events(&block)
            it "generates a stop event for the old run_id, and start events for the new run_id" do
              original_start_event = Models::AppStartEvent.filter(:app_guid => app.guid).all[0]

              yield(app)

              app.save

              Models::AppStopEvent.filter(
                :app_guid => app.guid,
                :app_run_id => original_start_event.app_run_id
              ).count.should == 1

              Models::AppStartEvent.filter(
                :app_guid => app.guid
              ).all.last.app_run_id.should_not == original_start_event.app_run_id
            end
          end

          context "change in memory" do
            it_emits_app_start_and_stop_events do |app|
              app.memory = 512
            end
          end

          context "change in production flag" do
            it_emits_app_start_and_stop_events do |app|
              app.production = true
            end
          end

          context "change in instances" do
            it_emits_app_start_and_stop_events do |app|
              app.instances = 5
            end
          end
        end
      end
    end

    describe "quota" do
      let(:quota) do
        Models::QuotaDefinition.make(:memory_limit => 128)
      end

      context "app creation" do
        it "should raise error when quota is exceeded" do
          org = Models::Organization.make(:quota_definition => quota)
          space = Models::Space.make(:organization => org)
          expect do
            Models::App.make(:space => space,
              :memory => 65,
              :instances => 2)
          end.to raise_error(Sequel::ValidationFailed,
            /memory quota_exceeded/)
        end

        it "should not raise error when quota is not exceeded" do
          org = Models::Organization.make(:quota_definition => quota)
          space = Models::Space.make(:organization => org)
          expect do
            Models::App.make(:space => space,
              :memory => 64,
              :instances => 2)
          end.to_not raise_error
        end
      end

      context "app update" do
        it "should raise error when quota is exceeded" do
          org = Models::Organization.make(:quota_definition => quota)
          space = Models::Space.make(:organization => org)
          app = Models::App.make(:space => space,
            :memory => 64,
            :instances => 2)
          app.memory = 65
          expect { app.save }.to raise_error(Sequel::ValidationFailed,
            /memory quota_exceeded/)
        end

        it "should not raise error when quota is not exceeded" do
          org = Models::Organization.make(:quota_definition => quota)
          space = Models::Space.make(:organization => org)
          app = Models::App.make(:space => space,
            :memory => 63,
            :instances => 2)
          app.memory = 64
          expect { app.save }.to_not raise_error
        end
      end
    end

    describe "file_descriptors" do
      subject { Models::App.make }
      its(:file_descriptors) { should == 16_384 }
    end

    describe "changes to the app that trigger staging/dea notifications" do
      # Mark app as staged when AppStager.stage_app is called
      before do
        AppStager.stub(:stage_app) do |app, options={}, &success_callback|
          app.droplet_hash = "droplet-hash"
          success_callback.call
          AppStagerTask::Response.new({})
        end
      end

      def self.it_does_not_stage
        it "does not stage app" do
          AppStager.should_not_receive(:stage_app)
          expect {
            update
          }.to_not change { subject.last_stager_response }.from(nil)
        end
      end

      def self.it_stages
        it "stages sync" do
          AppStager.should_receive(:stage_app).with(subject, :async => false)
          expect {
            subject.stage_async = false
            update
          }.to change { subject.last_stager_response }.from(nil)
        end

        it "stages async" do
          AppStager.should_receive(:stage_app).with(subject, :async => true)
          expect {
            subject.stage_async = true
            update
          }.to change { subject.last_stager_response }.from(nil)
        end
      end

      describe "update instance count" do
        let!(:before_update_instances) { subject.instances }
        let!(:after_update_instances) { subject.instances+1 }

        def update
          subject.instances = after_update_instances
          subject.save
        end

        def self.it_does_not_notify_dea
          it "does not notify dea of app update" do
            DeaClient.should_not_receive(:change_running_instances)
            MessageBus.instance.should_not_receive(:publish)
            update
          end
        end

        def self.it_notifies_dea
          it "notifies dea of update" do
            DeaClient.should_receive(:change_running_instances).with(subject, after_update_instances)
            MessageBus.instance.should_receive(:publish).with(
              "droplet.updated",
              json_match(hash_including(
                "droplet" => subject.guid,
              )),
            )
            update
          end
        end

        context "when app is stopped and already staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is already started and already staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_notifies_dea
        end

        context "when app is stopped and not staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is already started and not staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc") }
          it_stages
          it_notifies_dea
        end
      end

      describe "updating state to STOPPED" do
        def update
          subject.state = "STOPPED"
          subject.save
        end

        def self.it_does_not_notify_dea
          it "does not notify dea of stop or update" do
            DeaClient.should_not_receive(:stop)
            MessageBus.instance.should_not_receive(:publish)
            update
          end
        end

        def self.it_notifies_dea
          it "notifies dea of stop and update" do
            DeaClient.should_receive(:stop).with(subject)
            MessageBus.instance.should_receive(:publish).with(
              "droplet.updated",
              json_match(hash_including(
                "droplet" => subject.guid,
              )),
            )
            update
          end
        end

        context "when app is stopped and already staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is already started and already staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_notifies_dea
        end

        context "when app is stopped and not staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is already started and not staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc") }
          it_does_not_stage
          it_notifies_dea
        end
      end

      describe "updating state to STARTED" do
        def update
          subject.state = "STARTED"
          subject.save
        end

        def self.it_does_not_notify_dea
          it "does not notify dea of app update" do
            DeaClient.should_not_receive(:start)
            MessageBus.instance.should_not_receive(:publish)
            update
          end
        end

        def self.it_notifies_dea
          it "notifies dea of start and update" do
            DeaClient.should_receive(:start).with(subject)
            MessageBus.instance.should_receive(:publish).with(
              "droplet.updated",
              json_match(hash_including(
                "droplet" => subject.guid,
              )),
            )
            update
          end
        end

        context "when app is stopped and already staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_notifies_dea
        end

        context "when app is already started and already staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is stopped and not staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc") }
          it_stages
          it_notifies_dea
        end

        # Original change to app that moved state into STARTED staged the app and notified dea
        context "when app is already started and not staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc") }
          it_does_not_stage
          it_does_not_notify_dea
        end
      end

      describe "app deletion" do
        def update
          subject.destroy
        end

        def self.it_does_not_notify_dea
          it "does not notify dea of app update" do
            DeaClient.should_not_receive(:stop)
            update
          end
        end

        def self.it_notifies_dea
          it "notifies dea to stop" do
            DeaClient.should_receive(:stop).with(subject)
            update
          end
        end

        context "when app is stopped and already staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is already started and already staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc", :droplet_hash => "def") }
          it_does_not_stage
          it_notifies_dea
        end

        context "when app is stopped and not staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is already started and not staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc") }
          it_does_not_stage
          it_notifies_dea
        end
      end
    end

    describe "#to_hash" do
      let(:app) { Models::App.make }
      subject { app.to_hash }

      it "has the space guid correctly formatted" do
        should include("space" => { "guid" => app.space_guid })
      end

      it "has the framework guid correctly formatted" do
        should include("framework" => { "guid" => app.framework_guid })
      end

      it "has the runtime guid correctly formatted" do
        should include("runtime" => { "guid" => app.runtime_guid })
      end
    end
  end
end
