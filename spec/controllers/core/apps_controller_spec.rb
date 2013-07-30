require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppsController, type: :controller do
    before { configure_stacks }
    include_examples "uaa authenticated api", path: "/v2/apps"
    include_examples "querying objects", path: "/v2/apps", model: Models::App, queryable_attributes: %w(name)
    include_examples "enumerating objects", path: "/v2/apps", model: Models::App
    include_examples "reading a valid object", path: "/v2/apps", model: Models::App, basic_attributes: %w(name space_guid stack_guid)
    include_examples "operations on an invalid object", path: "/v2/apps"
    include_examples "creating and updating", path: "/v2/apps", model: Models::App,
                     required_attributes: %w(name space_guid),
                     unique_attributes: %w(name space_guid)
    include_examples "deleting a valid object", path: "/v2/apps", model: Models::App, one_to_many_collection_ids: {
      :service_bindings => lambda { |app|
        service_instance = Models::ManagedServiceInstance.make(
          :space => app.space
        )
        Models::ServiceBinding.make(
          :app => app,
          :service_instance => service_instance
        )
      },
      :events => lambda { |app|
        Models::AppEvent.make(:app => app)
      }
    },
      one_to_many_collection_ids_without_url: {}

    include_examples "collection operations", path: "/v2/apps", model: Models::App,
      one_to_many_collection_ids: {
        service_bindings: lambda { |app|
          service_instance = Models::ManagedServiceInstance.make(space: app.space)
          Models::ServiceBinding.make(app: app, service_instance: service_instance)
        }
      },
      many_to_one_collection_ids: {
        space: lambda { |app| Models::Space.make },
        stack: lambda { |app| Models::Stack.make },
      },
      many_to_many_collection_ids: {
        routes: lambda { |app|
          domain = Models::Domain.make(owning_organization: app.space.organization)
          app.space.organization.add_domain(domain)
          app.space.add_domain(domain)
          Models::Route.make(domain: domain, space: app.space)
        }
      }

    describe "create app" do
      let(:space_guid) { Models::Space.make.guid.to_s }
      let(:initial_hash) do
        { :name => "maria",
          :space_guid => space_guid
        }
      end

      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      subject { post "/v2/apps", Yajl::Encoder.encode(initial_hash), json_headers(admin_headers) }

      context "when name and space provided" do
        it "responds with new app data" do
          subject
          last_response.status.should == 201
          decoded_response["entity"]["name"].should == "maria"
          decoded_response["entity"]["space_guid"].should == space_guid
        end
      end

      context "when memory is 0" do
        before do
          initial_hash[:memory] = 0
        end

        it "responds invalid arguments" do
          subject
          last_response.status.should == 400
          last_response.body.should match /invalid amount of memory/
        end
      end

      context "when name is not provided" do
        let(:initial_hash) {{ :space_guid => space_guid }}
        it "responds with missing field name error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /Error: Missing field name/
        end
      end

      context "when space is not provided" do
        let(:initial_hash) {{ :name => "maria" }}
        it "responds with missing field space error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /Error: Missing field space/
        end
      end

      context "when detected_buildpack is provided" do
        let(:initial_hash) do
          { :name => "maria",
            :space_guid => space_guid,
            :detected_buildpack => "buildpack"
          }
        end

        it "responds with error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /.*error.*detected_buildpack.*/i
        end
      end

      it "records a app.create event" do
        subject

        last_response.status.should == 201

        new_app_guid = decoded_response['metadata']['guid']
        event = Models::Event.find(:type => "app.create", :actee => new_app_guid)

        expect(event).to be
        expect(event.actor).to eq(admin_user.guid)
      end
    end

    describe "update app" do
      let(:update_hash) { {} }

      let(:app_obj) { Models::App.make(:detected_buildpack => "buildpack-name") }

      subject { put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers) }

      describe "update app debug" do
        context "set debug" do
          let(:update_hash) do
            {"debug" => "run"}
          end

          it "should work" do
            subject
            app_obj.refresh
            app_obj.debug.should == "run"
            last_response.status.should == 201
          end
                    
        end
        
        context "change debug" do
          let(:app_obj) { Models::App.make(:debug => "run") }

          let(:update_hash) do
            {"debug" => "suspend"}
          end

          it "should work" do
            subject
            app_obj.refresh
            app_obj.debug.should == "suspend"
            last_response.status.should == 201
          end
        end

        context "reset debug" do
          let(:app_obj) { Models::App.make(:debug => "run") }

          let(:update_hash) do
            {"debug" => "none"}
          end

          it "should work" do
            subject
            app_obj.refresh
            app_obj.debug.should be_nil
            last_response.status.should == 201
          end
        end

        context "passing in nil" do
          let(:app_obj) { Models::App.make(:debug => "run") }

          let(:update_hash) do
            {"debug" => nil}
          end

          it "should do nothing" do
            subject
            app_obj.refresh
            app_obj.debug.should == "run"
            last_response.status.should == 201
          end
        end
      end

        
      context "when detected buildpack is not provided" do
        let(:update_hash) do
          {}
        end

        it "should work" do
          subject
          last_response.status.should == 201
        end
      end

      context "when detected buildpack is provided" do
        before { update_hash[:detected_buildpack] = "buildpack" }

        it "should raise error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /.*error.*detected_buildpack.*/i
        end
      end

      context "when the app is already deleted" do
        let(:app_obj) { Models::App.make(:detected_buildpack => "buildpack-name") }

        before { app_obj.soft_delete }

        it "should raise error" do
          subject

          last_response.status.should == 404
        end
      end

      describe "events" do
        before { update_hash[:instances] = 2 }

        it "registers an app.start event" do
          subject

          event = Models::Event.find(:type => "app.update", :actee => app_obj.guid)
          expect(event).to be
          expect(event.actor).to eq(admin_user.guid)
        end
      end
    end

    describe "read an app" do
      let(:app_obj) { Models::App.make(:detected_buildpack => "buildpack-name") }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      subject { get "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers) }

      it "should return the detected buildpack" do
        subject
        last_response.status.should == 200
        decoded_response["entity"]["detected_buildpack"].should eq("buildpack-name")
      end

      context "when the app is already deleted" do
        let(:app_obj) { Models::App.make(:detected_buildpack => "buildpack-name") }

        before do
          app_obj.soft_delete
        end

        it "should raise error" do
          subject
          last_response.status.should == 404
        end
      end
    end

    describe "delete an app" do
      let(:app_obj) { Models::App.make }

      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      subject { delete "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers) }

      context "when the app is not deleted" do
        let(:app_obj) { Models::App.make }

        it "should delete the app" do
          subject
          last_response.status.should == 204
        end
      end

      context "when the app is already deleted" do
        let(:app_obj) { Models::App.make }

        before do
          app_obj.soft_delete
        end

        it "should raise error" do
          subject
          last_response.status.should == 404
        end
      end

      context "when the app is running" do
        let(:app_obj) { Models::App.make :state => "STARTED", :package_hash => "abc" }

        it "tells the DEAs to stop it" do
          called = false
          DeaClient.should_receive(:stop) do |app|
            app.guid.should == app_obj.guid
            called = true
          end

          subject

          called.should be_true
        end

        it "registers a billing stop event" do
          called = false
          Models::AppStopEvent.should_receive(:create_from_app) do |app|
            app.guid.should == app_obj.guid
            called = true
          end

          subject

          called.should be_true
        end
      end

      context "recursive deletion with dependencies" do
        let!(:app_event) { Models::AppEvent.make(:app => app_obj) }
        let!(:route) { Models::Route.make(:space => app_obj.space) }

        before do
          app_obj.add_route(route)
          app_obj.save
        end

        subject { delete "/v2/apps/#{app_obj.guid}?recursive=true", {}, json_headers(admin_headers) }

        it "should delete the dependencies" do
          subject
          last_response.status.should == 204

          Models::App.deleted[:id => app_obj.id].deleted_at.should_not be_nil
          Models::App.deleted[:id => app_obj.id].not_deleted.should be_nil
          Models::AppEvent.find(:id => app_event.id).should_not be_nil
        end
      end

      context "non recursive deletion with app events" do
        let!(:app_event) { Models::AppEvent.make(:app => app_obj) }

        context "with other empty associations" do
          it "should soft delete the app and NOT delete the app event" do
            subject

            last_response.status.should == 204
            Models::App.deleted[:id => app_obj.id].deleted_at.should_not be_nil
            Models::App.deleted[:id => app_obj.id].not_deleted.should be_nil
            Models::AppEvent.find(:id => app_event.id).should_not be_nil
          end
        end

        context "with NON-empty service_binding (one_to_many) association" do
          let!(:svc_instance) { Models::ManagedServiceInstance.make(:space => app_obj.space) }
          let!(:service_binding) { Models::ServiceBinding.make(:app => app_obj, :service_instance => svc_instance) }

          it "should raise an error" do
            subject

            last_response.status.should == 400
            decoded_response["description"].should =~ /service_bindings/i
          end
        end

      end

      it "records an app.deleted event" do
        subject
        last_response.status.should == 204
        event = Models::Event.find(:type => "app.delete", :actee => app_obj.guid)
        expect(event).to be
        expect(event.actor).to eq(admin_user.guid)
      end
    end

    describe "validations" do
      let(:app_obj)   { Models::App.make }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      describe "env" do
        it "should allow an empty environment" do
          hash = {}
          update_hash = { :environment_json => hash }

          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
          last_response.status.should == 201
        end

        it "should allow multiple variables" do
          hash = { :abc => 123, :def => "hi" }
          update_hash = { :environment_json => hash }
          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
          last_response.status.should == 201
        end

        [ "VMC", "vmc", "VCAP", "vcap" ].each do |k|
          it "should not allow entries to start with #{k}" do
            hash = { :abc => 123, "#{k}_abc" => "hi" }
            update_hash = { :environment_json => hash }
            put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
            last_response.status.should == 400
            decoded_response["description"].should match /environment_json reserved_key:#{k}_abc/
          end
        end
      end
    end

    describe "command" do
      let(:app_obj)   { Models::App.make }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      it "should have no command entry in the metadata if not provided" do
        get "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers)
        last_response.status.should == 200
        decoded_response["entity"]["command"].should be_nil
        decoded_response["entity"]["metadata"].should be_nil
      end

      it "should set the command on the app metadata" do
        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:command => "foobar"), json_headers(admin_headers)
        last_response.status.should == 201
        decoded_response["entity"]["command"].should == "foobar"
        decoded_response["entity"]["metadata"].should be_nil
      end
    end

    describe "staging" do
      context "when app will be staged" do
        let(:app_obj) do
          Models::App.make(:package_hash => "abc", :state => "STOPPED",
                           :droplet_hash => nil, :package_state => "PENDING",
                           :instances => 1)
        end

        it "stages the app asynchronously" do
          received_app = nil

          AppManager.should_receive(:stage_app) do |app|
            received_app = app
            AppStagerTask::Response.new({})
          end

          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
          received_app.id.should == app_obj.id
        end

        it "returns X-App-Staging-Log header with staging log url" do
          stager_response = AppStagerTask::Response.new(:task_streaming_log_url => "streaming-log-url")
          AppManager.stub(:stage_app => stager_response)

          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
          last_response.status.should == 201
          last_response.headers["X-App-Staging-Log"].should == "streaming-log-url"
          end
      end

      context "when app will not be staged" do
        let(:app_obj) { Models::App.make(:state => "STOPPED") }

        it "does not add X-App-Staging-Log" do
          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode({}), json_headers(admin_headers)
          last_response.status.should == 201
          last_response.headers.should_not have_key("X-App-Staging-Log")
        end
      end
    end

    describe "on route change" do
      let(:space) { Models::Space.make }
      let(:domain) do
        space.add_domain(
          :name => "jesse.cloud",
          :wildcard => true,
          :owning_organization => space.organization,
        )
      end

      before :each do
        reset_database

        user = make_developer_for_space(space)
        # keeping the headers here so that it doesn't reset the global config...
        @headers_for_user = headers_for(user)
        @app = Models::App.make(
          :space => space,
          :state => "STARTED",
          :package_hash => "abc",
          :droplet_hash => "def",
          :package_state => "STAGED",
        )
        @app_url = "/v2/apps/#{@app.guid}"
      end

      it "tells the dea client to update when we add one url through PUT /v2/apps/:guid" do
        route = domain.add_route(
          :host => "app",
          :space => space,
        )

        DeaClient.should_receive(:update_uris).with(an_instance_of(VCAP::CloudController::Models::App)) do |app|
          expect(app.uris).to include("app.jesse.cloud")
        end

        put(
          @app_url,
          AppsController::UpdateMessage.new(
            :route_guids => [route.guid],
          ).encode,
          json_headers(@headers_for_user)
        )
        last_response.status.should == 201
      end

      it "tells the dea client to update when we remove a url through PUT /v2/apps/:guid" do
        bar_route = @app.add_route(
          :host => "bar",
          :space => space,
          :domain => domain,
        )
        route = @app.add_route(
          :host => "foo",
          :space => space,
          :domain => domain,
        )
        get "#{@app_url}/routes", {}, @headers_for_user
        decoded_response["resources"].map { |r|
          r["metadata"]["guid"]
        }.sort.should == [bar_route.guid, route.guid].sort

        DeaClient.should_receive(:update_uris).with(an_instance_of(VCAP::CloudController::Models::App)) do |app|
          expect(app.uris).to include("foo.jesse.cloud")
        end

        put(
          @app_url,
          AppsController::UpdateMessage.new(
            :route_guids => [route.guid],
          ).encode,
          json_headers(@headers_for_user)
        )
        last_response.status.should == 201
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = Models::App.make(:space => @space_a)
        @obj_b = Models::App.make(:space => @space_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :name => Sham.name,
          :space_guid => @space_a.guid)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission checks", "OrgManager",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission checks", "OrgUser",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission checks", "BillingManager",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission checks", "Auditor",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission checks", "SpaceManager",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 1,
            :create => :allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission checks", "SpaceAuditor",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end

    describe "Quota enforcement" do
      let(:quota) { Models::QuotaDefinition.make(:memory_limit => 0) }

      context "quota" do
        it "should enforce quota check on memory" do
          org = Models::Organization.make(:quota_definition => quota)
          space = Models::Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :memory => 128)

          post "/v2/apps", req, json_headers(headers_for(make_developer_for_space(space)))

          last_response.status.should == 400
          decoded_response["description"].should =~ /exceeded your organization's memory limit/
        end
      end
    end
  end
end
