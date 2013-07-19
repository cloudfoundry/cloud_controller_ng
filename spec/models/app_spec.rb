require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Models::App do
    let(:org) { Models::Organization.make }
    let(:space) { Models::Space.make(:organization => org) }

    let(:domain) do
      Models::Domain.make(:owning_organization => org).tap do |d|
        org.add_domain(d)
        space.add_domain(d)
      end
    end

    let(:route) { Models::Route.make(:domain => domain, :space => space) }

    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :space],
      :unique_attributes => [ [:space, :name] ],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :space => {
          :delete_ok => true,
          :create_for => lambda { |app| Models::Space.make },
        },
        :stack => {
          :delete_ok => true,
          :create_for => lambda { |app| Models::Stack.make },
        }
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
        },
        :events => lambda { |app|
          Models::AppEvent.make(:app => app)
        }
      }
    }

    describe ".deleted" do
      it "includes deleted apps" do
        app = Models::App.make
        app.soft_delete
        Models::App.deleted[:id => app.id].should_not be_nil
      end

      it "does not include non-deleted apps" do
        app = Models::App.make
        Models::App.deleted[:id => app.id].should be_nil
      end
    end

    describe ".existing" do
      it "includes non-deleted apps" do
        app = Models::App.make
        Models::App.existing[:id => app.id].should_not be_nil
      end

      it "does not include deleted apps" do
        deleted_app = Models::App.make
        deleted_app.soft_delete
        Models::App.existing[:id => deleted_app.id].should be_nil
      end
    end

    describe ".with_deleted" do
      it "includes both deleted and non-deleted apps" do
        app = Models::App.make
        deleted_app = Models::App.make
        deleted_app.soft_delete
        Models::App.with_deleted[:id => app.id].should_not be_nil
        Models::App.with_deleted[:id => deleted_app.id].should_not be_nil
      end
    end

    describe "#stack" do
      def self.it_always_sets_stack
        context "when stack was already set" do
          let(:stack) { Models::Stack.make }
          before { subject.stack = stack }

          it "keeps previously set stack" do
            subject.save
            subject.refresh
            subject.stack.should == stack
          end
        end

        context "when stack was set to nil" do
          before do
            subject.stack = nil
            Models::Stack.default.should_not be_nil
          end

          it "is populated with default stack" do
            subject.save
            subject.refresh
            subject.stack.should == Models::Stack.default
          end
        end
      end

      context "when app is being created" do
        subject do
          Models::App.new(
            :name => Sham.name,
            :space => space,
          )
        end
        it_always_sets_stack
      end

      context "when app is being updated" do
        subject { Models::App.make }
        it_always_sets_stack
      end
    end

    describe "#stack=" do
      let(:new_stack) { Models::Stack.make }

      context "app was not staged before" do
        subject { Models::App.new }

        it "doesn't mark the app for staging" do
          subject.stack = new_stack
          subject.staged?.should be_false
          subject.needs_staging?.should be_false
        end
      end

      context "app needs staging" do
        subject { Models::App.make(
          :package_hash => "package-hash",
          :package_state => "PENDING",
          :instances => 1,
          :state => "STARTED"
        ) }

        it "keeps app as needs staging" do
          subject.stack = new_stack
          subject.staged?.should be_false
          subject.needs_staging?.should be_true
        end
      end

      context "app is already staged" do
        subject { Models::App.make(:package_hash => "package-hash", :instances => 1, :state => "STARTED") }
        before { subject.droplet_hash = "droplet-hash" }

        it "marks the app for re-staging" do
          expect {
            subject.stack = new_stack
          }.to change { subject.needs_staging? }.from(false).to(true)
        end

        it "does not consider app as staged" do
          expect {
            subject.stack = new_stack
          }.to change { subject.staged? }.from(true).to(false)
        end
      end
    end

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
        }.to raise_error(Models::App::InvalidRouteRelation, /URL was not available/)
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
        app = Models::App.make(:environment_json => {"jesse" => "awesome"})
        app.environment_json.should eq("jesse" => "awesome")
      end

      def self.it_does_not_mark_for_re_staging
        it "does not mark an app for restage" do
          app = Models::App.make(
            :package_hash => "deadbeef",
            :package_state => "STAGED",
            :environment_json => old_env_json,
          )

          expect {
            app.environment_json = new_env_json
            app.save
          }.to_not change { app.needs_staging? }
        end
      end

      context "if env changes" do
        let(:old_env_json) { {} }
        let(:new_env_json) { {"key" => "value"} }
        it_does_not_mark_for_re_staging
      end

      context "if BUNDLE_WITHOUT in env changes" do
        let(:old_env_json) { {"BUNDLE_WITHOUT" => "test"} }
        let(:new_env_json) { {"BUNDLE_WITHOUT" => "development"} }
        it_does_not_mark_for_re_staging
      end

      describe "env is encrypted" do
        let(:env) { {"jesse" => "awesome"} }
        let!(:app) { Models::App.make(:environment_json => env) }
        let(:last_row) { VCAP::CloudController::Models::App.dataset.naked.order_by(:id).last }

        it "is encrypted" do
          expect(last_row[:environment_json]).not_to eq Yajl::Encoder.encode(env).to_s
        end

        it "is decrypted" do
          app.reload
          expect(app.environment_json).to eq env
        end

        it "salt is unique for each app" do
          app_2 = Models::App.make(:environment_json => env)
          expect(app.salt).not_to eq app_2.salt
        end

        it "must have a salt of length 8" do
          expect(app.salt.length).to eq 8
        end

        #it_behaves_like "a model with an encrypted attribute" do
        #  let(:encrypted_attr) { :environment_json }
        #  let(:value_to_encrypt) { env }
        #end
      end
    end

    describe "metadata" do
      it "deserializes the serialized value" do
        app = Models::App.make(
          :metadata => {"jesse" => "super awesome"},
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
      describe "name" do
        let(:space) { Models::Space.make }

        it "does not allow the same name in a different case", :skip_sqlite => true do
          Models::App.make(:name => "lowercase", :space => space)

          expect {
            Models::App.make(:name => "lowerCase", :space => space)
          }.to raise_error(Sequel::ValidationFailed, /space_id and name/)
        end
      end

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
          app.environment_json = {:abc => 123, :def => "hi"}
          app.should be_valid
        end

        ["VMC", "vmc", "VCAP", "vcap"].each do |k|
          it "should not allow entries to start with #{k}" do
            app.environment_json = {:abc => 123, "#{k}_abc" => "hi"}
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
          app.metadata = {:abc => 123, :def => "hi"}
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

    describe "pending?" do
      let(:app) { Models::App.make }

      it "should return true if package_state is PENDING" do
        app.package_state = "PENDING"
        app.pending?.should be_true
      end

      it "should return false if package_state is not PENDING" do
        app.package_state = "STARTED"
        app.pending?.should be_false
      end
    end

    describe "failed?" do
      let(:app) { Models::App.make }

      it "should return true if package_state is FAILED" do
        app.package_state = "FAILED"
        app.failed?.should be_true
      end

      it "should return false if package_state is not FAILED" do
        app.package_state = "STARTED"
        app.failed?.should be_false
      end
    end

    describe "needs_staging?" do
      subject(:app) { Models::App.make }

      context "when the app is started" do
        before do
          app.state = "STARTED"
          app.instances = 1
        end

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

      context "when the app is not started" do
        before do
          app.state = "STOPPED"
          app.package_hash = "abc"
          app.package_state = "PENDING"
        end

        it 'should return false' do
          app.should_not be_needs_staging
        end
      end

      context "when the app has no instances" do
        before do
          app.state = "STARTED"
          app.package_hash = "abc"
          app.package_state = "PENDING"
          app.instances = 0
        end

        it { should_not be_needs_staging }
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

    describe "kill_after_multiple_restarts?" do
      let(:app) { Models::App.make }

      it "defaults to false" do
        expect(app.kill_after_multiple_restarts?).to eq false
      end

      it "can be set to true" do
        app.kill_after_multiple_restarts = true
        expect(app.kill_after_multiple_restarts?).to eq true
      end
    end

    describe "version" do
      let(:app) { Models::App.make(:package_hash => "abc", :package_state => "STAGED") }

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
        app.state = "STARTED"
        app.instances = 1
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
          :space => space,
          :stack => Models::Stack.make)
        app.add_route_by_guid(route.guid)
        app.save
        app.routes.should == [route]
      end

      it "should not allow a route on a domain from another org" do
        app = Models::App.new(:name => Sham.name,
          :space => space,
          :stack => Models::Stack.make)
        app.add_route_by_guid(Models::Route.make.guid)
        expect { app.save }.to raise_error(Models::App::InvalidRouteRelation)
        app.routes.should be_empty
      end
    end

    describe "destroy" do
      let(:app) { Models::App.make(:package_hash => "abc", :package_state => "STAGED", :space => space) }

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
        AppManager.should_receive(:delete_droplet).with(app)
        app.destroy
      end

      it "should remove the package" do
        AppPackage.should_receive(:delete_package).with(app.guid)
        app.destroy
      end

      it "should nullify the routes" do
        app.add_route(route)
        expect {
          app.destroy
        }.to change { route.apps }.from([app]).to([])
      end

      it "should destroy all dependent service bindings" do
        service_binding = Models::ServiceBinding.make(
          :app => app,
          :service_instance => Models::ManagedServiceInstance.make(:space => app.space)
        )
        expect {
          app.destroy
        }.to change { Models::ServiceBinding.where(:id => service_binding.id).count }.from(1).to(0)
      end

      it "should destroy all dependent crash events" do
        app_event = Models::AppEvent.make(:app => app)

        expect {
          app.destroy
        }.to change {
          Models::AppEvent.where(:id => app_event.id).count
        }.from(1).to(0)
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
            Models::App.make(:state => "STARTED", :package_hash => "abc", :package_state => "STAGED")
          end
        end

        context "starting a stopped app" do
          it "generates a start event" do
            app = Models::App.make(:state => "STOPPED")
            Models::AppStartEvent.should_receive(:create_from_app).with(app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STARTED", :package_hash => "abc", :package_state => "STAGED")
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
            app = Models::App.make(:state => "STARTED", :package_hash => "abc", :package_state => "STAGED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_receive(:create_from_app).with(app)
            app.update(:state => "STOPPED")
          end
        end

        context "updating a started app" do
          it "does not generate a start or stop event" do
            app = Models::App.make(:state => "STARTED", :package_hash => "abc", :package_state => "STAGED")
            Models::AppStartEvent.should_not_receive(:create_from_app)
            Models::AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STARTED")
          end
        end

        context "deleting a started app" do
          let(:app) do
            app = Models::App.make(:state => "STARTED", :package_hash => "abc", :package_state => "STAGED")
            app_org = app.space.organization
            app_org.billing_enabled = true
            app_org.save(:validate => false) # because we need to force enable billing
            app
          end

          before do
            Models::AppStartEvent.create_from_app(app)
            VCAP::CloudController::DeaClient.stub(:stop)
          end

          it "generates a stop event" do
            Models::AppStopEvent.should_receive(:create_from_app).with(app)
            app.destroy
          end

          context "when the stop event creation fails" do
            before do
              Models::AppStopEvent.stub(:create_from_app).with(app).and_raise("boom")
            end

            it "rolls back the deletion" do
              expect { app.destroy rescue nil }.not_to change(app, :exists?).from(true)
            end
          end

          context "when somehow there is already a stop event for the most recent start event" do
            it "succeeds and does not generate a duplicate stop event" do
              Models::AppStopEvent.create_from_app(app)
              Models::AppStopEvent.should_not_receive(:create_from_app).with(app)
              app.destroy
            end
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
            app.package_hash = "abc"
            app.package_state = "STAGED"
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

        it "can delete an app that somehow has exceeded its memory quota" do
          org = Models::Organization.make(:quota_definition => quota)
          space = Models::Space.make(:organization => org)
          app = Models::App.make(:space => space,
            :memory => 64,
            :instances => 2)

          quota.memory_limit = 32
          quota.save

          app.state = "STOPPED"
          expect { app.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)
          expect { app.delete }.not_to raise_error
        end
      end
    end

    describe "file_descriptors" do
      subject { Models::App.make }
      its(:file_descriptors) { should == 16_384 }
    end

    describe "changes to the app that trigger staging/dea notifications" do
      subject { Models::App.make :droplet_hash => nil, :package_state => "PENDING", :instances => 1, :state => "STARTED" }

      # Mark app as staged when AppManager.stage_app is called
      before do
        AppManager.stub(:stage_app) do |app, &success_callback|
          app.droplet_hash = "droplet-hash"
          success_callback.call(:started_instances => 1)
          AppStagerTask::Response.new({})
        end
      end

      def self.it_does_not_stage
        it "does not stage app" do
          AppManager.should_not_receive(:stage_app)
          expect {
            update
          }.to_not change { subject.last_stager_response }.from(nil)
        end
      end

      def self.it_stages
        it "stages" do
          AppManager.should_receive(:stage_app).with(subject)
          expect {
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
            HealthManagerClient.should_not_receive(:notify_app_updated)
            update
          end
        end

        def self.it_notifies_dea
          it "notifies dea of update" do
            DeaClient.should_receive(:change_running_instances).with(subject, after_update_instances)
            HealthManagerClient.should_receive(:notify_app_updated).with(subject.guid)
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
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc", :droplet_hash => nil, :package_state => "PENDING") }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is already started and not staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc", :droplet_hash => nil, :package_state => "PENDING") }
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
            HealthManagerClient.should_not_receive(:notify_app_updated)
            update
          end
        end

        def self.it_notifies_dea
          it "notifies dea of stop and update" do
            DeaClient.should_receive(:stop).with(subject)
            HealthManagerClient.should_receive(:notify_app_updated).with(subject.guid)
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
        let(:instances_to_start) { 0 }
        def update
          subject.state = "STARTED"
          subject.save
        end

        def self.it_does_not_notify_dea
          it "does not notify dea of app update" do
            DeaClient.should_not_receive(:start)
            HealthManagerClient.should_not_receive(:notify_app_updated)
            update
          end
        end

        def self.it_notifies_dea
          it "notifies dea of start and update" do
            DeaClient.should_receive(:start).with(subject, :instances_to_start => instances_to_start)
            HealthManagerClient.should_receive(:notify_app_updated).with(subject.guid)
            update
          end
        end

        context "when app is stopped and already staged" do
          let(:instances_to_start) { 1 }

          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc", :droplet_hash => "def", :instances => 1) }
          it_does_not_stage
          it_notifies_dea
        end

        context "when app is already started and already staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc", :droplet_hash => "def", :instances => 1) }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app is stopped and not staged" do
          subject { Models::App.make(:state => "STOPPED", :package_hash => "abc", :droplet_hash => nil, :package_state => "PENDING", :instances => 1) }
          it_stages
          it_notifies_dea
        end

        # Original change to app that moved state into STARTED staged the app and notified dea
        context "when app is already started and not staged" do
          subject { Models::App.make(:state => "STARTED", :package_hash => "abc", :droplet_hash => nil, :package_state => "PENDING", :instances => 1) }
          it_does_not_stage
          it_does_not_notify_dea
        end

        context "when app has no bits" do
          subject { Models::App.make(:state => "STARTED", :package_hash => nil) }

          it "raises an AppPackageInvalid exception" do
            expect {
              update
            }.to raise_error(VCAP::Errors::AppPackageInvalid)
          end
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

    describe "soft deletion" do
      let(:app_obj) { Models::App.make(:detected_buildpack => "buildpack-name") }

      it "should not allow the same object to be deleted twice" do
        app_obj.soft_delete
        expect { app_obj.soft_delete }.to raise_error(Models::App::AlreadyDeletedError)
      end

      it "does not show up in normal queries" do
        expect {
          app_obj.soft_delete
        }.to change { Models::App[:guid => app_obj.guid] }.to(nil)
      end

      context "with app events" do
        let!(:app_event) { Models::AppEvent.make(:app => app_obj) }

        context "with other empty associations" do
          it "should soft delete the app" do
            app_obj.soft_delete
          end
        end

        context "with NON-empty deletable associations" do
          context "with NON-empty service_binding associations" do
            let!(:svc_instance) { Models::ManagedServiceInstance.make(:space => app_obj.space) }
            let!(:service_binding) { Models::ServiceBinding.make(:app => app_obj, :service_instance => svc_instance) }

            it "should delete the service bindings" do
              app_obj.soft_delete

              Models::ServiceBinding.find(:id => service_binding.id).should be_nil
            end
          end
        end

        context "with NON-empty nullifyable associations" do
          context "with NON-empty routes associations" do
            let!(:route) { Models::Route.make(:space => app_obj.space) }

            before do
              app_obj.add_route(route)
              app_obj.save
            end

            it "should nullify routes" do
              app_obj.soft_delete

              deleted_app = Models::App.deleted[:id => app_obj.id]
              deleted_app.routes.should be_empty
              route.apps.should be_empty
            end
          end
        end

        after do
          Models::AppEvent.where(:id => app_event.id).should_not be_empty
          Models::App.deleted[:id => app_obj.id].deleted_at.should_not be_nil
          Models::App.deleted[:id => app_obj.id].not_deleted.should be_false
        end
      end

      context "recreation" do
        describe "create an already soft deleted app" do
          before do
            app_obj.soft_delete
          end

          it "should allow recreation and soft deletion of a soft deleted app" do
            expect do
              deleted_app = Models::App.make(:space => app_obj.space, :name => app_obj.name)
              deleted_app.soft_delete
            end.to_not raise_error
          end

          it "should allow only 1 active recreation at a time" do
            expect do
              Models::App.make(:space => app_obj.space, :name => app_obj.name)
            end.to_not raise_error

            expect do
              Models::App.make(:space => app_obj.space, :name => app_obj.name)
            end.to raise_error
          end
        end
      end
    end
  end
end
