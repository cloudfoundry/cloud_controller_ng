# encoding: utf-8
require "spec_helper"

module VCAP::CloudController
  describe App, type: :model do
    let(:org) { Organization.make }
    let(:space) { Space.make(:organization => org) }

    let(:domain) { PrivateDomain.make(:owning_organization => org) }

    let(:route) { Route.make(:domain => domain, :space => space) }

    def enable_custom_buildpacks
      App.stub(:custom_buildpacks_enabled?) { true }
    end

    def disable_custom_buildpacks
      App.stub(:custom_buildpacks_enabled?) { false }
    end

    before do
      client = double('broker client', unbind: nil, deprovision: nil)
      Service.any_instance.stub(:client).and_return(client)
      VCAP::CloudController::Seeds.create_seed_stacks(config)

      enable_custom_buildpacks
    end

    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :space],
      :unique_attributes => [ [:space, :name] ],
      :custom_attributes_for_uniqueness_tests => ->{ {stack: Stack.make} },
      :stripped_string_attributes => :name,
      :many_to_one => {
        :space => {
          :delete_ok => true,
          :create_for => lambda { |app| Space.make },
        },
        :stack => {
          :delete_ok => true,
          :create_for => lambda { |app| Stack.make },
        }
      },
      :one_to_zero_or_more => {
        :service_bindings => lambda { |app|
          service_binding = ServiceBinding.make
          service_binding.service_instance.space = app.space
          service_binding
        },
        :routes => lambda { |app|
          domain = PrivateDomain.make(
            :owning_organization => app.space.organization
          )
          Route.make(
            :domain => domain,
            :space => app.space
          )
        },
        :events => lambda { |app|
          AppEvent.make(:app => app)
        }
      }
    }

    describe "#audit_hash" do
      it "should return uncensored data unchanged" do
        request_hash = { "key" => "value", "key2" => "value2" }
        expect(App.audit_hash(request_hash)).to eq(request_hash)
      end

      it "should obfuscate censored data" do
        request_hash = { "command" => "PASSWORD=foo ./start" }
        expect(App.audit_hash(request_hash)).to eq({ "command" => "PRIVATE DATA HIDDEN" })
      end
    end

    describe "#stack" do
      def self.it_always_sets_stack
        context "when stack was already set" do
          let(:stack) { Stack.make }
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
            Stack.default.should_not be_nil
          end

          it "is populated with default stack" do
            subject.save
            subject.refresh
            subject.stack.should == Stack.default
          end
        end
      end

      context "when app is being created" do
        subject do
          App.new(
            :name => Sham.name,
            :space => space,
          )
        end
        it_always_sets_stack
      end

      context "when app is being updated" do
        subject { AppFactory.make }
        it_always_sets_stack
      end
    end

    describe "#stack=" do
      let(:new_stack) { Stack.make }

      context "app was not staged before" do
        subject { App.new }

        it "doesn't mark the app for staging" do
          subject.stack = new_stack
          subject.staged?.should be_false
          subject.needs_staging?.should be_false
        end
      end

      context "app needs staging" do
        subject { AppFactory.make(
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
        subject do
          AppFactory.make(
            package_hash: "package-hash",
            instances: 1,
            droplet_hash: "droplet-hash",
            state: "STARTED")
        end

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

    describe "current_droplet" do
      context "app is already staged" do
        subject do
          AppFactory.make(
            package_hash: "package-hash",
            instances: 1,
            droplet_hash: "droplet-hash")
        end

        it "knows its current droplet" do
          expect(subject.current_droplet).to be_instance_of(Droplet)
          expect(subject.current_droplet.droplet_hash).to eq("droplet-hash")

          new_droplet_hash = "new droplet hash"
          subject.add_new_droplet(new_droplet_hash)
          expect(subject.current_droplet.droplet_hash).to eq(new_droplet_hash)
        end

        context "When it does not have a row in droplets table but has droplet hash column", droplet_cleanup: true do
          before do
            subject.droplet_hash = "A-hash"
            subject.save
            subject.droplets_dataset.destroy
          end

          it "knows its current droplet" do
            expect(subject.current_droplet).to be_instance_of(Droplet)
            expect(subject.current_droplet.droplet_hash).to eq("A-hash")
          end
        end

        context "When the droplet hash is nil" do
          it "should return nul" do
            app_without_droplet = AppFactory.make(droplet_hash: nil)
            expect(app_without_droplet.current_droplet).to be_nil
          end
        end
      end
    end

    describe "bad relationships" do
      it "should not associate an app with a route on a different space" do
        app = AppFactory.make

        domain = PrivateDomain.make(
          :owning_organization => app.space.organization
        )

        other_space = Space.make(:organization => app.space.organization)

        route = Route.make(
          :space => other_space,
          :domain => domain,
        )

        expect {
          app.add_route(route)
        }.to raise_error(App::InvalidRouteRelation, /URL was not available/)
      end

      it "should not associate an app with a route created on another space with a shared domain" do
        shared_domain = SharedDomain.make
        app = AppFactory.make

        other_space = Space.make(:organization => app.space.organization)
        route = Route.make(
          :host => Sham.host,
          :space => other_space,
          :domain => shared_domain
        )

        expect {
          app.add_route(route)
        }.to raise_error App::InvalidRouteRelation
      end
    end

    describe "#environment_json" do
      it "deserializes the serialized value" do
        app = AppFactory.make(:environment_json => { "jesse" => "awesome" })
        app.environment_json.should eq("jesse" => "awesome")
      end

      def self.it_does_not_mark_for_re_staging
        it "does not mark an app for restage" do
          app = AppFactory.make(
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
        let(:new_env_json) { { "key" => "value" } }
        it_does_not_mark_for_re_staging
      end

      context "if BUNDLE_WITHOUT in env changes" do
        let(:old_env_json) { { "BUNDLE_WITHOUT" => "test" } }
        let(:new_env_json) { { "BUNDLE_WITHOUT" => "development" } }
        it_does_not_mark_for_re_staging
      end

      describe "env is encrypted" do
        let(:env) { { "jesse" => "awesome" } }
        let(:long_env) { { "many_os" => "o" * 10_000 } }
        let!(:app) { AppFactory.make(:environment_json => env) }
        let(:last_row) { VCAP::CloudController::App.dataset.naked.order_by(:id).last }

        it "is encrypted" do
          expect(last_row[:encrypted_environment_json]).not_to eq Yajl::Encoder.encode(env).to_s
        end

        it "is decrypted" do
          app.reload
          expect(app.environment_json).to eq env
        end

        it "does not store unecrypted environment json" do
          expect(last_row[:environment_json]).to be_nil
        end

        it "salt is unique for each app" do
          app_2 = AppFactory.make(:environment_json => env)
          expect(app.salt).not_to eq app_2.salt
        end

        it "must have a salt of length 8" do
          expect(app.salt.length).to eq 8
        end

        it "must deal with null env_json to remain null after encryption" do
          null_json_app = AppFactory.make()
          expect(null_json_app.environment_json).to be_nil
        end

        it "works with long serialized environments" do
          app = AppFactory.make(:environment_json => long_env)
          app.reload
          expect(app.environment_json).to eq(long_env)
        end
      end
    end

    describe "#database_uri" do
      let(:space) { Space.make }
      let(:app) { App.make(:environment_json => {"jesse" => "awesome"}, :space => space) }

      context "when there are database-like services" do
        before do
          sql_service_plan = ServicePlan.make(:service => Service.make(:label => "elephantsql-n/a"))
          sql_service_instance = ManagedServiceInstance.make(:space => space, :service_plan => sql_service_plan, :name => "elephantsql-vip-uat")
          sql_binding = ServiceBinding.make(:app => app, :service_instance => sql_service_instance, :credentials => {"uri" => "mysql://foo.com"})

          banana_service_plan = ServicePlan.make(:service => Service.make(:label => "chiquita-n/a"))
          banana_service_instance = ManagedServiceInstance.make(:space => space, :service_plan => banana_service_plan, :name => "chiqiuta-yummy")
          banana_binding = ServiceBinding.make(:app => app, :service_instance => banana_service_instance, :credentials => {"uri" => "banana://yum.com"})
        end

        it "returns database uri" do
          expect(app.database_uri).to eq("mysql2://foo.com")
        end
      end

      context "when there are non-database-like services" do
        before do
          banana_service_plan = ServicePlan.make(:service => Service.make(:label => "chiquita-n/a"))
          banana_service_instance = ManagedServiceInstance.make(:space => space, :service_plan => banana_service_plan, :name => "chiqiuta-yummy")
          banana_binding = ServiceBinding.make(:app => app, :service_instance => banana_service_instance, :credentials => {"uri" => "banana://yum.com"})

          uncredentialed_service_plan = ServicePlan.make(:service => Service.make(:label => "mysterious-n/a"))
          uncredentialed_service_instance = ManagedServiceInstance.make(:space => space, :service_plan => uncredentialed_service_plan, :name => "mysterious-mystery")
          uncredentialed_binding = ServiceBinding.make(:app => app, :service_instance => uncredentialed_service_instance, :credentials => {})
        end

        it "returns nil" do
          expect(app.database_uri).to be_nil
        end
      end

      context "when there are no services" do
        it "returns nil" do
          expect(app.database_uri).to be_nil
        end
      end
    end

    describe "#system_env_json" do
      before { pending("This attribute should remain hidden for now. We have a story to re-do this logic later") }
      context "when there are no services" do
        it "contains an empty vcap_services" do
          app = App.make(:environment_json => {"jesse" => "awesome"})
          expect(app.system_env_json["VCAP_SERVICES"]).to eq({})
        end
      end

      context "when there are services" do
        let(:space){Space.make}
        let(:app ){App.make(:environment_json => {"jesse" => "awesome"}, :space => space)}
        let(:service){Service.make(:label => "elephantsql-n/a")}
        let(:service_alt){Service.make(:label => "giraffesql-n/a")}
        let(:service_plan){ServicePlan.make(:service => service)}
        let(:service_plan_alt){ServicePlan.make(:service => service_alt)}
        let(:service_instance){ManagedServiceInstance.make(:space => space, :service_plan => service_plan, :name => "elephantsql-vip-uat")}
        let(:service_instance_same_label){ManagedServiceInstance.make(:space => space, :service_plan => service_plan, :name => "elephantsql-2")}
        let(:service_instance_diff_label){ManagedServiceInstance.make(:space => space, :service_plan => service_plan_alt, :name => "giraffesql-vip-uat")}

        before do
          ServiceBinding.make(:app => app, :service_instance => service_instance)
        end

        it "contains a popluated vcap_services" do
          expect(app.system_env_json["VCAP_SERVICES"]).not_to eq({})
          expect(app.system_env_json["VCAP_SERVICES"]).to have_key("#{service.label}-#{service.version}")
          expect(app.system_env_json["VCAP_SERVICES"]["#{service.label}-#{service.version}"]).to have(1).services
        end

        describe "service hash includes only white-listed keys" do
          subject(:service_hash_keys) do
            app.system_env_json["VCAP_SERVICES"]["#{service.label}-#{service.version}"].first.keys
          end

          its(:count) { should eq(5) }
          it { should include('name') }
          it { should include('label') }
          it { should include('tags') }
          it { should include('plan') }
          it { should include('credentials') }
        end

        describe "grouping" do
          before do
            ServiceBinding.make(:app => app, :service_instance => service_instance_same_label)
            ServiceBinding.make(:app => app, :service_instance => service_instance_diff_label)
          end

          it "should group services by label" do
            app.system_env_json["VCAP_SERVICES"].should have(2).groups
            app.system_env_json["VCAP_SERVICES"]["#{service.label}-#{service.version}"].should have(2).services
            app.system_env_json["VCAP_SERVICES"]["#{service_alt.label}-#{service_alt.version}"].should have(1).service
          end
        end
      end
    end

    describe "metadata" do
      it "deserializes the serialized value" do
        app = AppFactory.make(
          :metadata => { "jesse" => "super awesome" },
        )
        app.metadata.should eq("jesse" => "super awesome")
      end
    end

    describe "command" do
      it "stores the command in the metadata" do
        app = AppFactory.make(:command => "foobar")
        app.metadata.should eq("command" => "foobar")
        app.save
        app.metadata.should eq("command" => "foobar")
        app.refresh
        app.metadata.should eq("command" => "foobar")
      end

      it "saves the field as nil when initializing to empty string" do
        app = AppFactory.make(:command => "")
        app.metadata.should eq("command" => nil)
      end

      it "saves the field as nil when overriding to empty string" do
        app = AppFactory.make(:command => "echo hi")
        app.command = ""
        app.save
        app.refresh
        expect(app.metadata).to eq("command" => nil)
      end

      it "saves the field as nil when set to nil" do
        app = AppFactory.make(:command => "echo hi")
        app.command = nil
        app.save
        app.refresh
        expect(app.metadata).to eq("command" => nil)
      end
    end

    describe "console" do
      it "stores the command in the metadata" do
        app = AppFactory.make(:console => true)
        app.metadata.should eq("console" => true)
        app.save
        app.metadata.should eq("console" => true)
        app.refresh
        app.metadata.should eq("console" => true)
      end

      it "returns true if console was set to true" do
        app = AppFactory.make(:console => true)
        app.console.should == true
      end

      it "returns false if console was set to false" do
        app = AppFactory.make(:console => false)
        app.console.should == false
      end

      it "returns false if console was not set" do
        app = AppFactory.make
        app.console.should == false
      end
    end

    describe "debug" do
      it "stores the command in the metadata" do
        app = AppFactory.make(:debug => "suspend")
        app.metadata.should eq("debug" => "suspend")
        app.save
        app.metadata.should eq("debug" => "suspend")
        app.refresh
        app.metadata.should eq("debug" => "suspend")
      end

      it "returns nil if debug was explicitly set to nil" do
        app = AppFactory.make(:debug => nil)
        app.debug.should be_nil
      end

      it "returns nil if debug was not set" do
        app = AppFactory.make
        app.debug.should be_nil
      end
    end

    describe "buildpack=" do
      let(:valid_git_url) do
        "git://user@github.com:repo"
      end
      it "can be set to a git url" do
        app = App.new
        app.buildpack = valid_git_url
        expect(app.buildpack).to eql GitBasedBuildpack.new(valid_git_url)
      end

      it "can be set to a buildpack name" do
        buildpack = Buildpack.make
        app = App.new
        app.buildpack = buildpack.name
        expect(app.buildpack).to eql(buildpack)
      end

      context "switching between buildpacks" do
        it "allows changing from admin buildpacks to a git url" do
          buildpack = Buildpack.make
          app = App.new(buildpack: buildpack.name)
          app.buildpack = valid_git_url
          expect(app.buildpack).to eql(GitBasedBuildpack.new(valid_git_url))
        end

        it "allows changing from git url to admin buildpack" do
          buildpack = Buildpack.make
          app = App.new(buildpack: valid_git_url)
          app.buildpack = buildpack.name
          expect(app.buildpack).to eql(buildpack)
        end
      end
    end

    describe "validations" do
      describe "buildpack" do
        it "does allow nil value" do
          expect {
            AppFactory.make(buildpack: nil)
          }.to_not raise_error
        end

        context "when custom buildpacks are enabled" do
          it "does allow a public git url" do
            expect {
              AppFactory.make(buildpack: "git://user@github.com:repo")
            }.to_not raise_error
          end

          it "allows a public http url" do
            expect {
              AppFactory.make(buildpack: "http://example.com/foo")
            }.to_not raise_error
          end

          it "does allow a buildpack name" do
            admin_buildpack = VCAP::CloudController::Buildpack.make
            app = nil
            expect {
              app = AppFactory.make(buildpack: admin_buildpack.name)
            }.to_not raise_error

            expect(app.admin_buildpack).to eql(admin_buildpack)
          end

          it "does not allow a private git url" do
            expect {
              app = AppFactory.make(buildpack: "git@example.com:foo.git")
            }.to raise_error(Sequel::ValidationFailed, /is not valid public git url or a known buildpack name/)
          end

          it "does not allow a private git url with ssh schema" do
            expect {
              app = AppFactory.make(buildpack: "ssh://git@example.com:foo.git")
            }.to raise_error(Sequel::ValidationFailed, /is not valid public git url or a known buildpack name/)
          end
        end

        context "when custom buildpacks are disabled" do
          context "and the buildpack attribute is being changed" do
            before { disable_custom_buildpacks }

            it "does NOT allow a public git url" do
              expect {
                AppFactory.make(buildpack: "git://user@github.com:repo")
              }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
            end

            it "does NOT allow a public http url" do
              expect {
                AppFactory.make(buildpack: "http://example.com/foo")
              }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
            end

            it "does allow a buildpack name" do
              admin_buildpack = VCAP::CloudController::Buildpack.make
              app = nil
              expect {
                app = AppFactory.make(buildpack: admin_buildpack.name)
              }.to_not raise_error

              expect(app.admin_buildpack).to eql(admin_buildpack)
            end

            it "does not allow a private git url" do
              expect {
                app = AppFactory.make(buildpack: "git@example.com:foo.git")
              }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
            end

            it "does not allow a private git url with ssh schema" do
              expect {
                app = AppFactory.make(buildpack: "ssh://git@example.com:foo.git")
              }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
            end
          end

          context "and an attribute OTHER THAN buildpack is being changed" do
            it "permits the change even though the buildpack is still custom" do
              app = AppFactory.make(buildpack: "git://user@github.com:repo")

              disable_custom_buildpacks

              expect {
                app.instances = 2
                app.save
              }.to_not raise_error
            end
          end
        end

        it "does not allow a non-url string" do
          expect {
            app = AppFactory.make(buildpack: "Hello, world!")
          }.to raise_error(Sequel::ValidationFailed, /is not valid public git url or a known buildpack name/)
        end
      end

      describe "disk_quota" do
        let(:app) { AppFactory.make }

        it "allows any disk_quota below the maximum" do
          app.disk_quota = 1000
          expect{
            app.save
          }.to_not raise_error
        end

        it "does not allow a disk_quota above the maximum" do
          app.disk_quota = 3000
          expect{
            app.save
          }.to raise_error(Sequel::ValidationFailed, /too much disk/)
        end
      end

      describe "name" do
        let(:space) { Space.make }
        let(:app) { AppFactory.make }

        it "does not allow the same name in a different case", :skip_sqlite => true do
          AppFactory.make(:name => "lowercase", :space => space)

          expect {
            AppFactory.make(:name => "lowerCase", :space => space)
          }.to raise_error(Sequel::ValidationFailed, /space_id and name/)
        end

        it "should allow standard ascii characters" do
          app.name = "A -_- word 2!?()\'\"&+."
          expect{
            app.save
          }.to_not raise_error
        end

        it "should allow backslash characters" do
          app.name = "a \\ word"
          expect{
            app.save
          }.to_not raise_error
        end

        it "should allow unicode characters" do
          app.name = "防御力¡"
          expect{
            app.save
          }.to_not raise_error
        end

        it "should not allow newline characters" do
          app.name = "a \n word"
          expect{
            app.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should not allow escape characters" do
          app.name = "a \e word"
          expect{
            app.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe "env" do
        let(:app) { AppFactory.make }

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

        ["VMC", "vmc", "VCAP", "vcap"].each do |k|
          it "should not allow entries to start with #{k}" do
            app.environment_json = { :abc => 123, "#{k}_abc" => "hi" }
            app.should_not be_valid
          end
        end
      end

      describe "metadata" do
        let(:app) { AppFactory.make }

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

    describe "health_check_timeout" do
      before do
        config_override({ :maximum_health_check_timeout => 512 })
      end

      context "when the health_check_timeout was not specified" do
        it "should use nil as health_check_timeout" do
          app = AppFactory.make
          expect(app.health_check_timeout).to eq(nil)
        end

        it "should not raise error if value is nil" do
          expect {
            AppFactory.make(health_check_timeout: nil)
          }.to_not raise_error
        end
      end

      context "when a valid health_check_timeout is specified" do
        it "should use that value" do
          app = AppFactory.make(health_check_timeout: 256)
          expect(app.health_check_timeout).to eq(256)
        end
      end

      context "when a health_check_timeout exceeds the maximum" do
        it "should raise error" do
          expect {
            AppFactory.make(health_check_timeout: 1024)
          }.to raise_error(Sequel::ValidationFailed, /health_check_timeout maximum_exceeded/)
        end
      end

      it "should raise error if value is less than zero" do
        expect {
          AppFactory.make(health_check_timeout: -10)
        }.to raise_error(Sequel::ValidationFailed, /health_check_timeout less_than_zero/)
      end

      it "should not raise error if value is greater than zero" do
        expect {
          AppFactory.make(health_check_timeout: 10)
        }.to_not raise_error
      end
    end

    describe "package_hash=" do
      let(:app) { AppFactory.make(:package_hash => "abc", :package_state => "STAGED") }

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
      let(:app) { AppFactory.make }

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
      let(:app) { AppFactory.make }

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
      let(:app) { AppFactory.make }

      it "should return true if package_state is FAILED" do
        app.package_state = "FAILED"
        app.staging_failed?.should be_true
      end

      it "should return false if package_state is not FAILED" do
        app.package_state = "STARTED"
        app.staging_failed?.should be_false
      end
    end

    describe "needs_staging?" do
      subject(:app) { AppFactory.make }

      context "when the app is started" do
        before do
          app.state = "STARTED"
          app.instances = 1
        end

        it "should return false if the package_hash is nil" do
          app.package_hash = nil
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
      let(:app) { AppFactory.make }

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
      let(:app) { AppFactory.make }

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
      let(:app) { AppFactory.make }

      it "defaults to false" do
        expect(app.kill_after_multiple_restarts?).to eq false
      end

      it "can be set to true" do
        app.kill_after_multiple_restarts = true
        expect(app.kill_after_multiple_restarts?).to eq true
      end
    end

    describe "version" do
      let(:app) { AppFactory.make(:package_hash => "abc", :package_state => "STAGED") }

      it "should have a version on create" do
        app.version.should_not be_nil
      end

      it "should update the version when changing :state" do
        app.state = "STARTED"
        expect { app.save }.to change(app, :version)
      end

      it "should update the version on update of :state" do
        expect { app.update(:state => "STARTED") }.to change(app, :version)
      end

      context "for a started app" do
        before { app.update(:state => "STARTED") }

        it "should update the version when changing :memory" do
          app.memory = 2048
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

        context "when adding and removing routes" do
          let(:domain) do
            PrivateDomain.make :owning_organization => app.space.organization
          end

          let(:route) { Route.make :domain => domain, :space => app.space }

          it "updates the app's version" do
            expect { app.add_route(route) }.to change(app, :version)
            expect { app.remove_route(route) }.to change(app, :version)
          end
        end
      end
    end

    describe "droplet_hash=" do
      let(:app) { AppFactory.make }

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
        app = AppFactory.make(:space => space)
        app.add_route(route)
        app.uris.should == [route.fqdn]
      end
    end

    describe "adding routes to unsaved apps" do
      it "should set a route by guid on a new but unsaved app" do
        app = App.new(:name => Sham.name,
          :space => space,
          :stack => Stack.make)
        app.add_route_by_guid(route.guid)
        app.save
        app.routes.should == [route]
      end

      it "should not allow a route on a domain from another org" do
        app = App.new(:name => Sham.name,
          :space => space,
          :stack => Stack.make)
        app.add_route_by_guid(Route.make.guid)
        expect { app.save }.to raise_error(App::InvalidRouteRelation)
        app.routes.should be_empty
      end
    end

    describe "creation" do
      it "does not create an AppUsageEvent" do
        expect {
          App.create_from_hash(name: "awesome app" , space_guid: space.guid)
        }.not_to change {AppUsageEvent.count}
      end
    end

    describe "saving" do
      it "calls AppObserver.updated", non_transactional: true do
        app = AppFactory.make
        AppObserver.should_receive(:updated).with(app)
        app.update(instances: app.instances + 1)
      end

      context "when app state changes from STOPPED to STARTED" do
        it "creates an AppUsageEvent" do
          app = AppFactory.make
          expect {
            app.update(state: "STARTED")
          }.to change {AppUsageEvent.count}.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end
      end

      context "when app state changes from STARTED to STOPPED" do
        it "creates an AppUsageEvent" do
          app = AppFactory.make(package_hash: "abc", state: "STARTED")
          expect {
            app.update(state: "STOPPED")
          }.to change {AppUsageEvent.count}.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end
      end

      context "when app instances changes" do
        it "creates an AppUsageEvent when the app is STARTED" do
          app = AppFactory.make(package_hash: "abc", state: "STARTED")
          expect {
            app.update(instances: 2)
          }.to change {AppUsageEvent.count}.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end

        it "does not create an AppUsageEvent when the app is STOPPED" do
          app = AppFactory.make(package_hash: "abc", state: "STOPPED")
          expect {
            app.update(instances: 2)
          }.not_to change {AppUsageEvent.count}
        end
      end

      context "when app memory changes" do
        it "creates an AppUsageEvent when the app is STARTED" do
          app = AppFactory.make(package_hash: "abc", state: "STARTED")
          expect {
            app.update(memory: 2)
          }.to change {AppUsageEvent.count}.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end

        it "does not create an AppUsageEvent when the app is STOPPED" do
          app = AppFactory.make(package_hash: "abc", state: "STOPPED")
          expect {
            app.update(memory: 2)
          }.not_to change {AppUsageEvent.count}
        end
      end
    end

    describe "destroy" do
      let(:app) { AppFactory.make(package_hash: "abc", package_state: "STAGED", space: space) }

      it "notifies the app observer", non_transactional: true do
        AppObserver.should_receive(:deleted).with(app)
        app.destroy
      end

      it "should nullify the routes" do
        app.add_route(route)
        expect {
          app.destroy
        }.to change { route.reload.apps.collect(&:guid) }.from([app.guid]).to([])
      end

      it "should destroy all dependent service bindings" do
        service_binding = ServiceBinding.make(
          :app => app,
          :service_instance => ManagedServiceInstance.make(:space => app.space)
        )
        expect {
          app.destroy
        }.to change { ServiceBinding.where(:id => service_binding.id).count }.from(1).to(0)
      end

      it "should destroy all dependent crash events" do
        app_event = AppEvent.make(:app => app)

        expect {
          app.destroy
        }.to change {
          AppEvent.where(:id => app_event.id).count
        }.from(1).to(0)
      end

      it "creates an AppUsageEvent when the app state is STARTED" do
        app = AppFactory.make(package_hash: "abc", package_state: "STAGED", space: space, state: "STARTED")
        expect {
          app.destroy
        }.to change { AppUsageEvent.count }.by(1)
        expect(AppUsageEvent.last).to match_app(app)
      end

      it "does not create an AppUsageEvent when the app state is STOPPED" do
        app = AppFactory.make(package_hash: "abc", package_state: "STAGED", space: space, state: "STOPPED")
        expect {
          app.destroy
        }.not_to change { AppUsageEvent.count }
      end

      it "locks the record when destroying" do
        app.should_receive(:lock!)
        app.destroy
      end
    end

    describe "billing", deprecated_billing: true do
      context "app state changes" do
        context "creating a stopped app" do
          it "does not generate a start event or stop event" do
            AppStartEvent.should_not_receive(:create_from_app)
            AppStopEvent.should_not_receive(:create_from_app)
            AppFactory.make(:state => "STOPPED")
          end
        end

        context "starting a stopped app" do
          it "generates a start event" do
            app = AppFactory.make(:state => "STOPPED")
            AppStartEvent.should_receive(:create_from_app).with(app)
            AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STARTED", :package_hash => "abc", :package_state => "STAGED")
          end
        end

        context "updating a stopped app" do
          it "does not generate a start event or stop event" do
            app = AppFactory.make(:state => "STOPPED")
            AppStartEvent.should_not_receive(:create_from_app)
            AppStopEvent.should_not_receive(:create_from_app)
            app.update(:state => "STOPPED")
          end
        end

        context "stopping a started app" do
          it "does not generate a start event, but generates a stop event" do
            app = AppFactory.make(state: "STARTED", :package_hash => "abc", :package_state => "STAGED")
            AppStartEvent.should_not_receive(:create_from_app)
            AppStopEvent.should_receive(:create_from_app).with(app)
            app.update(state: "STOPPED")
          end
        end

        context "updating a started app" do
          it "does not generate a start or stop event" do
            app = AppFactory.make(state: "STARTED", package_hash: "abc", package_state: "STAGED")
            AppStartEvent.should_not_receive(:create_from_app)
            AppStopEvent.should_not_receive(:create_from_app)
            app.update(state: "STARTED")
          end
        end

        context "deleting a started app" do
          let(:app) do
            app = AppFactory.make(state: "STARTED", package_hash: "abc", package_state: "STAGED")
            app_org = app.space.organization
            app_org.billing_enabled = true
            app_org.save(:validate => false) # because we need to force enable billing
            app
          end

          before do
            AppStartEvent.create_from_app(app)
            VCAP::CloudController::DeaClient.stub(:stop)
          end

          it "generates a stop event" do
            AppStopEvent.should_receive(:create_from_app).with(app)
            app.destroy(savepoint: true)
          end

          context "when the stop event creation fails" do
            before do
              AppStopEvent.stub(:create_from_app).with(app).and_raise("boom")
            end

            it "rolls back the deletion" do
              expect { app.destroy(savepoint: true) rescue nil }.not_to change(app, :exists?).from(true)
            end
          end

          context "when somehow there is already a stop event for the most recent start event" do
            it "succeeds and does not generate a duplicate stop event" do
              AppStopEvent.create_from_app(app)
              AppStopEvent.should_not_receive(:create_from_app).with(app)
              app.destroy(savepoint: true)
            end
          end
        end

        context "deleting a stopped app" do
          it "does not generate a stop event" do
            app = AppFactory.make(:state => "STOPPED")
            AppStopEvent.should_not_receive(:create_from_app)
            app.destroy(savepoint: true)
          end
        end
      end

      context "footprint changes" do
        let(:app) do
          app = AppFactory.make
          app_org = app.space.organization
          app_org.billing_enabled = true
          app_org.save(:validate => false) # because we need to force enable billing
          app
        end

        context "new app" do
          it "does not generate a start event or stop event" do
            AppStartEvent.should_not_receive(:create_from_app)
            AppStopEvent.should_not_receive(:create_from_app)
            app
          end
        end

        context "no change in footprint" do
          it "does not generate a start event or stop event" do
            AppStartEvent.should_not_receive(:create_from_app)
            AppStopEvent.should_not_receive(:create_from_app)
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
              original_start_event = AppStartEvent.filter(:app_guid => app.guid).all[0]

              yield(app)

              app.save

              AppStopEvent.filter(
                :app_guid => app.guid,
                :app_run_id => original_start_event.app_run_id
              ).count.should == 1

              AppStartEvent.filter(
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
        QuotaDefinition.make(:memory_limit => 128)
      end

      context "app creation" do
        it "should raise error when quota is exceeded" do
          org = Organization.make(:quota_definition => quota)
          space = Space.make(:organization => org)
          expect do
            AppFactory.make(:space => space,
              :memory => 65,
              :instances => 2)
          end.to raise_error(Sequel::ValidationFailed,
            /memory quota_exceeded/)
        end

        it "should not raise error when quota is not exceeded" do
          org = Organization.make(:quota_definition => quota)
          space = Space.make(:organization => org)
          expect do
            AppFactory.make(:space => space,
              :memory => 64,
              :instances => 2)
          end.to_not raise_error
        end
      end

      context "app update" do
        let(:org) { Organization.make(:quota_definition => quota) }
        let(:space) { Space.make(:organization => org) }
        let!(:app) { AppFactory.make(:space => space, :memory => 64, :instances => 2) }

        it "should raise error when quota is exceeded" do
          app.memory = 65
          expect { app.save }.to raise_error(Sequel::ValidationFailed,
            /memory quota_exceeded/)
        end

        it "should not raise error when quota is not exceeded" do
          app.memory = 63
          expect { app.save }.to_not raise_error
        end

        it "can delete an app that somehow has exceeded its memory quota" do
          quota.memory_limit = 32
          quota.save
          app.memory = 100
          expect { app.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)
          expect { app.delete }.not_to raise_error
        end

        it "allows scaling down instances of an app from above quota to below quota" do
          org.quota_definition = QuotaDefinition.make(:memory_limit => 72)
          act_as_cf_admin {org.save}

          app.reload
          app.instances = 1

          app.save

          app.reload
          expect(app.instances).to eq(1)
        end

        it "raises when scaling down number of instances but remaining above quota" do
          org.quota_definition = QuotaDefinition.make(:memory_limit => 32)
          act_as_cf_admin {org.save}

          app.reload
          app.instances = 1

          expect { app.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)
          app.reload
          expect(app.instances).to eq(2)
        end

        it "allows stopping an app that is above quota" do
          app.update(:state => "STARTED",
            :package_hash => "abc",
            :package_state => "STAGED",
            :droplet_hash => "def")

          org.quota_definition = QuotaDefinition.make(:memory_limit => 72)
          act_as_cf_admin {org.save}

          app.reload
          app.state = "STOPPED"

          app.save

          app.reload
          expect(app).to be_stopped
        end

        it "allows reducing memory from above quota to at/below quota" do
          org.quota_definition = QuotaDefinition.make(:memory_limit => 64)
          act_as_cf_admin {org.save}

          app.memory = 40
          expect { app.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)

          app.memory = 32
          app.save
          expect(app.memory).to eq(32)
        end

        it "should raise an error if instances is less than zero" do
          org = Organization.make(:quota_definition => quota)
          space = Space.make(:organization => org)
          app = AppFactory.make(:space => space,
                                :memory => 64,
                                :instances => 1)

          app.instances = -1
          expect { app.save }.to raise_error(Sequel::ValidationFailed, /instances less_than_zero/)
        end
      end
    end

    describe "file_descriptors" do
      subject { AppFactory.make }
      its(:file_descriptors) { should == 16_384 }
    end

    describe ".configure" do
      before do
        described_class.unstub(:custom_buildpacks_enabled?)
        described_class.configure(false)
      end

      it "sets whether custom buildpacks are enabled" do
        expect {
          described_class.configure(true)
        }.to change {
          described_class.custom_buildpacks_enabled?
        }.from(false).to(true)
      end
    end
  end
end
