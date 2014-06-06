require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppsController do
    before { configure_stacks }
    it_behaves_like "an authenticated endpoint", path: "/v2/apps"
    include_examples "querying objects", path: "/v2/apps", model: App, queryable_attributes: %w(name)
    include_examples "enumerating objects", path: "/v2/apps", model: App
    include_examples "reading a valid object", path: "/v2/apps", model: App, basic_attributes: %w(name space_guid stack_guid)
    include_examples "operations on an invalid object", path: "/v2/apps"
    include_examples "creating and updating", path: "/v2/apps", model: App,
                     required_attributes: %w(name space_guid),
                     unique_attributes: %w(name space_guid)
    include_examples "deleting a valid object", path: "/v2/apps", model: App, one_to_many_collection_ids: {
      :service_bindings => lambda { |app|
        service_instance = ManagedServiceInstance.make(
          :space => app.space
        )
        ServiceBinding.make(
          :app => app,
          :service_instance => service_instance
        )
      },
      :events => lambda { |app|
        AppEvent.make(:app => app)
      }
    }, :excluded => [ :events ]

    include_examples "collection operations", path: "/v2/apps", model: App,
      one_to_many_collection_ids: {
        service_bindings: lambda { |app|
          service_instance = ManagedServiceInstance.make(space: app.space)
          ServiceBinding.make(app: app, service_instance: service_instance)
        }
      },
      many_to_one_collection_ids: {
        space: lambda { |app| Space.make },
        stack: lambda { |app| Stack.make },
      },
      many_to_many_collection_ids: {
        routes: lambda { |app|
          domain = PrivateDomain.make(owning_organization: app.space.organization)
          Route.make(domain: domain, space: app.space)
        }
      }

    let(:app_event_repository) { CloudController::DependencyLocator.instance.app_event_repository }

    describe "create app" do
      let(:space) { Space.make }
      let(:space_guid) { space.guid.to_s }
      let(:initial_hash) do
        {
          name: "maria",
          space_guid: space_guid
        }
      end

      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      def create_app
        post "/v2/apps", Yajl::Encoder.encode(initial_hash), json_headers(admin_headers)
      end

      context "when name and space provided" do
        it "responds with new app data" do
          create_app
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
          create_app
          last_response.status.should == 400
          last_response.body.should match /invalid amount of memory/
        end
      end

      context "when default memory is configured" do
        let (:default_memory) { 200 }

        before do
          config_override({ :default_app_memory => default_memory })
        end

        it "uses the configured default when no memory is specified" do
          create_app
          decoded_response["entity"]["memory"].should == default_memory
        end
      end

      context "disk quota" do
         let (:default_disk) { 512 }

        before do
          config_override({ :default_app_disk_in_mb => default_disk })
        end

        it "uses the configured default when no quota is specified" do
          create_app
          decoded_response["entity"]["disk_quota"].should == default_disk
        end
        context "when disk quota provided" do
           let(:provided_disk) { 256 }
             
           before do
             initial_hash[:disk_quota] = provided_disk
           end
 
           it "uses the provided disk quota" do
             create_app
             decoded_response["entity"]["disk_quota"].should == provided_disk
           end
         end
      end

      context "when instances is less than 0" do
        before do
          initial_hash[:instances] = -1
        end

        it "responds invalid arguments" do
          create_app
          last_response.status.should == 400
          last_response.body.should match /instances less than 1/
        end
      end

      context "when name is not provided" do
        let(:initial_hash) {{ :space_guid => space_guid }}
        it "responds with missing field name error" do
          create_app
          last_response.status.should == 400
          last_response.body.should match /Error: Missing field name/
        end
      end

      context "when space is not provided" do
        let(:initial_hash) {{ :name => "maria" }}
        it "responds with missing field space error" do
          create_app
          last_response.status.should == 400
          last_response.body.should match /Error: Missing field space/
        end
      end

      context "when detected_buildpack is provided" do
        before { initial_hash[:detected_buildpack] = 'buildpack-name' }

        it "ignores the attribute" do
          expect { create_app }.to change(App, :count).by(1)
          last_response.status.should == 201

          app = App.last
          expect(app.detected_buildpack).to be_nil
          expect(decoded_response['entity'].fetch('detected_buildpack')).to be_nil
        end
      end

      describe "events" do
        it "records app create" do
          expected_attrs = AppsController::CreateMessage.decode(initial_hash.to_json).extract(stringify_keys: true)

          allow(app_event_repository).to receive(:record_app_create).and_call_original

          create_app
          expect(app_event_repository).to have_received(:record_app_create).with(App.last, admin_user, SecurityContext.current_user_email, expected_attrs)
        end
      end

      context "buildpacks" do
        it "accepts the buildpack in git formats" do
          initial_hash[:buildpack] = "git://user@public.example.com"
          create_app
          expect(last_response.status).to eql 201
        end

        it "accepts a buildpack name uploaded by an admin before" do
          admin_buildpack = VCAP::CloudController::Buildpack.make
          initial_hash[:buildpack] = admin_buildpack.name
          create_app
          expect(last_response.status).to eql 201
        end

        it "reject invalid buildpack url " do
          initial_hash[:buildpack] = "not-a-git-repo"
          create_app
          expect(last_response.status).to eql 400
          expect(decoded_response["description"]).to match /is not valid public git url or a known buildpack name/
        end
      end

      context "when the org is suspended" do
        before do
          space.organization.update(status: "suspended")
        end

        it "does not allow user to create new app (spot check)" do
          post "/v2/apps", Yajl::Encoder.encode(initial_hash), json_headers(headers_for(make_developer_for_space(space)))
          last_response.status.should == 403
        end
      end

    end

    describe "update app" do
      let(:update_hash) { {} }

      let(:app_obj) { AppFactory.make(:detected_buildpack => "buildpack-name") }

      def update_app
        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
      end

      describe "update app health_check_timeout" do
        context "when health_check_timeout value is provided" do
          let(:update_hash) { {"health_check_timeout" => 80} }

          it "should set to provided value" do
            update_app
            app_obj.refresh
            app_obj.health_check_timeout.should == 80
            last_response.status.should == 201
          end
        end

        context "when health_check_timeout value is not provided" do
          let(:update_hash) { {} }

          it "should not return error" do
            update_app
            last_response.status.should == 201
          end
        end
      end

      describe "update app debug" do
        context "set debug" do
          let(:update_hash) do
            {"debug" => "run"}
          end

          it "should work" do
            update_app
            app_obj.refresh
            app_obj.debug.should == "run"
            last_response.status.should == 201
          end

        end

        context "change debug" do
          let(:app_obj) { AppFactory.make(:debug => "run") }

          let(:update_hash) do
            {"debug" => "suspend"}
          end

          it "should work" do
            update_app
            app_obj.refresh
            app_obj.debug.should == "suspend"
            last_response.status.should == 201
          end
        end

        context "reset debug" do
          let(:app_obj) { AppFactory.make(:debug => "run") }

          let(:update_hash) do
            {"debug" => "none"}
          end

          it "should work" do
            update_app
            app_obj.refresh
            app_obj.debug.should be_nil
            last_response.status.should == 201
          end
        end

        context "passing in nil" do
          let(:app_obj) { AppFactory.make(:debug => "run") }

          let(:update_hash) do
            {"debug" => nil}
          end

          it "should do nothing" do
            update_app
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
          update_app
          last_response.status.should == 201
        end
      end

      context "when detected buildpack is provided" do
        before { update_hash[:detected_buildpack] = 'new-buildpack-name' }

        it "should ignore the attribute" do
          update_app

          last_response.status.should == 201

          app_obj.reload
          expect(app_obj.detected_buildpack).to be == 'buildpack-name'
          expect(decoded_response['entity'].fetch('detected_buildpack')).to be == 'buildpack-name'
        end
      end

      context "when package_state is provided" do
        before { update_hash[:package_state] = 'FAILED' }

        it "ignores the attribute" do
          update_app

          last_response.status.should == 201

          app_obj.reload
          expect(app_obj.package_state).to_not be == 'FAILED'
          expect(parse(last_response.body)["entity"]).not_to include("package_state" => "FAILED")
        end
      end

      describe "events" do
        let(:update_hash) { {instances: 2, foo: "foo_value"} }

        context "when the update succeeds" do
          it "records app update with whitelisted attributes" do
            allow(app_event_repository).to receive(:record_app_update).and_call_original

            expect(app_event_repository).to receive(:record_app_update) do |recorded_app, user, user_name, attributes|
              expect(recorded_app.guid).to eq(app_obj.guid)
              expect(recorded_app.instances).to eq(2)
              expect(user).to eq(admin_user)
              expect(user_name).to eq(SecurityContext.current_user_email)
              expect(attributes).to eq({"instances" => 2})
            end

            update_app
          end
        end

        context "when the update fails" do
          before do
            allow_any_instance_of(App).to receive(:update_from_hash).and_raise("Error saving")
            allow(app_event_repository).to receive(:record_app_update)
          end

          it "does not record app update" do
            update_app

            expect(app_event_repository).to_not have_received(:record_app_update)
            expect(last_response.status).to eq(500)
          end
        end
      end
    end

    describe "read an app" do
      let(:app_obj) { AppFactory.make(:detected_buildpack => "buildpack-name") }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      def get_app
        get "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers)
      end

      it "should return the detected buildpack" do
        get_app
        last_response.status.should == 200
        decoded_response["entity"]["detected_buildpack"].should eq("buildpack-name")
      end

      it "should not return the detected buildpack guid" do
        get_app
        last_response.status.should == 200
        decoded_response["entity"].should_not have_key("detected_buildpack_guid")
      end

      it "should not return the detected buildpack name" do
        get_app
        last_response.status.should == 200
        decoded_response["entity"].should_not have_key("detected_buildpack_name")
      end

      it "should return the package state" do
        get_app
        last_response.status.should == 200
        expect(parse(last_response.body)["entity"]).to have_key("package_state")
      end

      it "should not return system_env_json" do
        get_app
        last_response.status.should == 200
        expect(parse(last_response.body)["entity"]).not_to have_key("system_env_json")
      end
    end

    describe "delete an app" do
      let(:app_obj) { AppFactory.make }

      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      def delete_app
        delete "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers)
      end

      context "when the app is not deleted" do
        let(:app_obj) { AppFactory.make }

        it "should delete the app" do
          delete_app
          last_response.status.should == 204
        end
      end

      context "when the app is running" do
        let(:app_obj) { AppFactory.make :state => "STARTED", :package_hash => "abc" }
        it "registers a billing stop event" do
          called = false
          AppStopEvent.should_receive(:create_from_app) do |app|
            app.guid.should == app_obj.guid
            called = true
          end

          delete_app

          called.should be_true
        end
      end

      context "recursive deletion with dependencies" do
        let!(:app_event) { AppEvent.make(:app => app_obj) }
        let!(:route) { Route.make(:space => app_obj.space) }

        before do
          app_obj.add_route(route)
          app_obj.save
        end

        def delete_app_recursively
          delete "/v2/apps/#{app_obj.guid}?recursive=true", {}, json_headers(admin_headers)
        end

        it "should delete the dependencies" do
          delete_app_recursively
          last_response.status.should == 204

          App.find(id: app_obj.id).should be_nil
          AppEvent.find(:id => app_event.id).should be_nil
        end
      end

      context "non recursive deletion" do
        context "with other empty associations" do
          it "should destroy the app" do
            delete_app

            last_response.status.should == 204
            App.find(id: app_obj.id).should be_nil
          end
        end

        context "with NON-empty service_binding (one_to_many) association" do
          let!(:svc_instance) { ManagedServiceInstance.make(:space => app_obj.space) }
          let!(:service_binding) { ServiceBinding.make(:app => app_obj, :service_instance => svc_instance) }

          it "should raise an error" do
            delete_app

            last_response.status.should == 400
            decoded_response["description"].should =~ /service_bindings/i
          end

          it "should succeed on a recursive delete" do
            delete "/v2/apps/#{app_obj.guid}?recursive=true", {}, json_headers(admin_headers)

            last_response.status.should == 204
          end
        end

      end

      describe "events" do
        it "records an app delete-request" do
          allow(app_event_repository).to receive(:record_app_delete_request).and_call_original

          delete_app

          expect(app_event_repository).to have_received(:record_app_delete_request).with(app_obj, admin_user, SecurityContext.current_user_email, false)
        end

        it "records the recursive query parameter when recursive"  do
          allow(app_event_repository).to receive(:record_app_delete_request).and_call_original

          delete "/v2/apps/#{app_obj.guid}?recursive=true", {}, json_headers(admin_headers)

          expect(app_event_repository).to have_received(:record_app_delete_request).with(app_obj, admin_user, SecurityContext.current_user_email, true)
        end
      end
    end

    describe "read an app's env" do
      let(:space)     { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:auditor) { make_auditor_for_space(space) }
      let(:app_obj) { AppFactory.make(detected_buildpack: "buildpack-name") }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      context 'when the user is a member of the space this app exists in' do
        let(:app_obj) { AppFactory.make(detected_buildpack: "buildpack-name", space: space) }

        context 'when the user is not a space developer' do
          it 'returns a JSON payload indicating they have permission to manage this instance' do
            get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(auditor, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('You are not authorized to perform the requested action')
          end
        end

        context 'when the user has only the cloud_controller.read scope' do
          it 'returns a JSON payload indicating they have permission to manage this instance' do
            get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(200)
            expect(parse(last_response.body)).to have_key("system_env_json")
            expect(parse(last_response.body)).to have_key("environment_json")
          end
        end

        context 'when the user is space dev and has service instance bound to application' do
          let!(:service_instance) { ManagedServiceInstance.make(space: app_obj.space) }
          let!(:service_binding) { ServiceBinding.make(app: app_obj, service_instance: service_instance) }

          it 'returns system environment with VCAP_SERVICES'do
            get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(200)

            expect(decoded_response["system_env_json"].size).to eq(1)
            expect(decoded_response["system_env_json"]).to have_key("VCAP_SERVICES")
          end
        end

        context 'when the user does not have the necessary scope' do
          it 'returns InvalidAuthToken' do
            get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer, {scopes: ['cloud_controller.write']}))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('Your token lacks the necessary scopes to access this resource.')
          end
        end
      end

      context 'when the user reads environment variables from the app endpoint using inline-relations-depth=2' do
        let!(:test_environment_json) { {'environ_key' => 'value' } }
        let!(:app_obj) { AppFactory.make(detected_buildpack: "buildpack-name",
                                         space:              space,
                                         environment_json:   test_environment_json) }
        let!(:service_instance) { ManagedServiceInstance.make(space: app_obj.space) }
        let!(:service_binding) { ServiceBinding.make(app: app_obj, service_instance: service_instance) }

        context 'when the user is a space developer' do
          it 'returns non-redacted environment values' do
            get '/v2/apps?inline-relations-depth=2', {}, json_headers(headers_for(developer, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(200)

            expect(decoded_response["resources"].first["entity"]["environment_json"]).to eq(test_environment_json)
            expect(decoded_response).not_to have_key("system_env_json")
          end
        end

        context 'when the user is not a space developer' do
          it 'returns redacted values' do
            get '/v2/apps?inline-relations-depth=2', {}, json_headers(headers_for(auditor, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(200)

            expect(decoded_response["resources"].first["entity"]["environment_json"]).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(decoded_response).not_to have_key("system_env_json")
          end
        end
      end

      context 'when the user is NOT a member of the space this instance exists in' do
        let(:app_obj) { AppFactory.make(detected_buildpack: "buildpack-name") }

        it 'returns a JSON payload indicating the user does not have permission to manage this instance' do
          get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql(403)
        end
      end

      context 'when the user has not authenticated with Cloud Controller' do
        let(:instance)  { ServiceInstance.make }
        let(:developer) { nil }

        it 'returns an error saying that the user is not authenticated' do
          get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the app does not exist' do
        it 'returns an error saying the app was not found' do
          get "/v2/apps/nonexistentappguid/env", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql 404
        end
      end
    end

    describe "validations" do
      let(:app_obj)   { AppFactory.make }
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
      let(:app_obj)   { AppFactory.make }
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

      it "can be cleared if a request arrives asking command to be an empty string" do
        app_obj.command = "echo hi"
        app_obj.save
        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:command => ""), json_headers(admin_headers)
        last_response.status.should == 201
        decoded_response["entity"]["command"].should be_nil
        decoded_response["entity"]["metadata"].should be_nil
      end
    end

    describe "health_check_timeout" do
      let(:app_obj)   { AppFactory.make }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      it "should have no health_check_timeout entry in the metadata if not provided" do
        get "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers)
        last_response.status.should == 200
        decoded_response["entity"]["health_check_timeout"].should be_nil
        decoded_response["entity"]["metadata"].should be_nil
      end

      it "should set the health_check_timeout on the app metadata if provided" do
        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:health_check_timeout => 100), json_headers(admin_headers)
        last_response.status.should == 201
        decoded_response["entity"]["health_check_timeout"].should == 100
        decoded_response["entity"]["metadata"].should be_nil
      end
    end

    describe "staging" do
      context "when app will be staged", non_transactional: true do
        let(:app_obj) do
          AppFactory.make(:package_hash => "abc", :state => "STOPPED",
                           :droplet_hash => nil, :package_state => "PENDING",
                           :instances => 1)
        end

        it "stages the app asynchronously" do
          received_app = nil

          AppObserver.should_receive(:stage_app) do |app|
            received_app = app
            AppStagerTask::Response.new({})
          end

          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
          received_app.id.should == app_obj.id
        end

        it "returns X-App-Staging-Log header with staging log url" do
          stager_response = AppStagerTask::Response.new("task_streaming_log_url" => "streaming-log-url")
          AppObserver.stub(stage_app: stager_response)

          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
          last_response.status.should == 201
          last_response.headers["X-App-Staging-Log"].should == "streaming-log-url"
        end
      end

      context "when app will not be staged" do
        let(:app_obj) { AppFactory.make(:state => "STOPPED") }

        it "does not add X-App-Staging-Log" do
          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode({}), json_headers(admin_headers)
          last_response.status.should == 201
          last_response.headers.should_not have_key("X-App-Staging-Log")
        end
      end
    end

    describe "on route change" do
      let(:space) { Space.make }
      let(:domain) do
        PrivateDomain.make(name: "jesse.cloud", owning_organization: space.organization)
      end

      before do
        user = make_developer_for_space(space)
        # keeping the headers here so that it doesn't reset the global config...
        @headers_for_user = headers_for(user)
        @app = AppFactory.make(
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

        DeaClient.should_receive(:update_uris).with(an_instance_of(VCAP::CloudController::App)) do |app|
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

        DeaClient.should_receive(:update_uris).with(an_instance_of(VCAP::CloudController::App)) do |app|
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
        @obj_a = AppFactory.make(:space => @space_a)
        @obj_b = AppFactory.make(:space => @space_b)
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

          include_examples "permission enumeration", "OrgManager",
            :name => 'app',
            :path => "/v2/apps",
            :enumerate => 1
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission enumeration", "OrgUser",
            :name => 'app',
            :path => "/v2/apps",
            :enumerate => 0
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission enumeration", "BillingManager",
            :name => 'app',
            :path => "/v2/apps",
            :enumerate => 0
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission enumeration", "Auditor",
            :name => 'app',
            :path => "/v2/apps",
            :enumerate => 0
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission enumeration", "SpaceManager",
            :name => 'app',
            :path => "/v2/apps",
            :enumerate => 1
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission enumeration", "Developer",
            :name => 'app',
            :path => "/v2/apps",
            :enumerate => 1
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
            :name => 'app',
            :path => "/v2/apps",
            :enumerate => 1
        end
      end
    end

    describe "Quota enforcement" do
      let(:quota) { QuotaDefinition.make(:memory_limit => 0) }

      context "quota" do
        it "should enforce quota check on memory" do
          org = Organization.make(:quota_definition => quota)
          space = Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :memory => 128)

          post "/v2/apps", req, json_headers(headers_for(make_developer_for_space(space)))

          last_response.status.should == 400
          decoded_response["description"].should =~ /exceeded your organization's memory limit/
        end
      end
    end

    describe "events associations (via AppEvents)" do
      it "does not return events with inline-relations-depth=0" do
        app = App.make
        get "/v2/apps/#{app.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
        expect(entity).to have_key("events_url")
        expect(entity).to_not have_key("events")
      end

      it "does not return events with inline-relations-depth=1 since app_events dataset is relatively expensive to query" do
        app = App.make
        get "/v2/apps/#{app.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
        expect(entity).to have_key("events_url")
        expect(entity).to_not have_key("events")
      end
    end
  end
end
