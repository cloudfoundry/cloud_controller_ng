require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppsController do
    let(:app_event_repository) { CloudController::DependencyLocator.instance.app_event_repository }

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:space_guid) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
                                                               buildpack: {type: "string"},
                                                               command: {type: "string"},
                                                               console: {type: "bool", default: false},
                                                               debug: {type: "string"},
                                                               disk_quota: {type: "integer"},
                                                               environment_json: {type: "hash", default: {}},
                                                               health_check_timeout: { type: "integer" },
                                                               instances: {type: "integer", default: 1},
                                                               memory: {type: "integer"},
                                                               name: {type: "string", required: true},
                                                               production: {type: "bool", default: false},
                                                               state: {type: "string", default: "STOPPED"},
                                                               event_guids: {type: "[string]"},
                                                               route_guids: {type: "[string]"},
                                                               space_guid: {type: "string", required: true},
                                                               stack_guid: {type: "string"},
                                                               docker_image: {type: "string", required: false},
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
                                                               buildpack: {type: "string"},
                                                               command: {type: "string"},
                                                               console: {type: "bool"},
                                                               debug: {type: "string"},
                                                               disk_quota: {type: "integer"},
                                                               environment_json: {type: "hash"},
                                                               health_check_timeout: {type: "integer"},
                                                               instances: {type: "integer"},
                                                               memory: {type: "integer"},
                                                               name: {type: "string"},
                                                               production: {type: "bool"},
                                                               state: {type: "string"},
                                                               event_guids: {type: "[string]"},
                                                               route_guids: {type: "[string]"},
                                                               service_binding_guids: {type: "[string]"},
                                                               space_guid: {type: "string"},
                                                               stack_guid: {type: "string"},
                                                               docker_image: {type: "string"},
        })
      end
    end

    describe "create app" do
      let(:space) { Space.make }
      let(:space_guid) { space.guid.to_s }
      let(:initial_hash) do
        {
          name: "maria",
          space_guid: space_guid
        }
      end

      let(:decoded_response) { MultiJson.load(last_response.body) }

      describe "events" do
        it "records app create" do
          expected_attrs = AppsController::CreateMessage.decode(initial_hash.to_json).extract(stringify_keys: true)

          allow(app_event_repository).to receive(:record_app_create).and_call_original

          post "/v2/apps", MultiJson.dump(initial_hash), json_headers(admin_headers)
          expect(app_event_repository).to have_received(:record_app_create).with(App.last, admin_user, SecurityContext.current_user_email, expected_attrs)
        end
      end

      context "when the org is suspended" do
        before do
          space.organization.update(status: "suspended")
        end

        it "does not allow user to create new app (spot check)" do
          post "/v2/apps", MultiJson.dump(initial_hash), json_headers(headers_for(make_developer_for_space(space)))
          expect(last_response.status).to eq(403)
        end
      end

    end

    describe "update app" do
      let(:update_hash) { {} }

      let(:app_obj) { AppFactory.make(:instances => 1) }

      def update_app
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(update_hash), json_headers(admin_headers)
      end

      describe "app_scaling feature flag" do
        let(:developer) { make_developer_for_space(app_obj.space) }

        context "when the flag is enabled" do
          before { FeatureFlag.make(name: "app_scaling", enabled: true) }

          it "allows updating memory" do
            put "/v2/apps/#{app_obj.guid}", '{ "memory": 2 }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(201)
          end
        end

        context "when the flag is disabled" do
          before { FeatureFlag.make(name: "app_scaling", enabled: false, error_message: nil) }

          it "fails with the proper error code and message" do
            put "/v2/apps/#{app_obj.guid}", '{ "memory": 2 }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(403)
            expect(decoded_response["error_code"]).to match(/FeatureDisabled/)
            expect(decoded_response["description"]).to match(/app_scaling/)
          end
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

    describe "delete an app" do
      let(:app_obj) { AppFactory.make }

      let(:decoded_response) { MultiJson.load(last_response.body) }

      def delete_app
        delete "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers)
      end

      it "deletes the app" do
        delete_app
        expect(last_response.status).to eq(204)
        expect(App.filter(id: app_obj.id)).to be_empty
      end

      context "non recursive deletion" do
        context "with NON-empty service_binding association" do
          let!(:svc_instance) { ManagedServiceInstance.make(:space => app_obj.space) }
          let!(:service_binding) { ServiceBinding.make(:app => app_obj, :service_instance => svc_instance) }

          it "should raise an error" do
            delete_app

            expect(last_response.status).to eq(400)
            expect(decoded_response["description"]).to match(/service_bindings/i)
          end

          it "should succeed on a recursive delete" do
            delete "/v2/apps/#{app_obj.guid}?recursive=true", {}, json_headers(admin_headers)

            expect(last_response.status).to eq(204)
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
      let(:decoded_response) { MultiJson.load(last_response.body) }

      context 'when the user is a member of the space this app exists in' do
        let(:app_obj) { AppFactory.make(detected_buildpack: "buildpack-name", space: space) }

        context 'when the user is not a space developer' do
          it 'returns a JSON payload indicating they do not have permission to manage this instance' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(auditor, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('You are not authorized to perform the requested action')
          end
        end

        context 'when the user has only the cloud_controller.read scope' do
          it 'returns successfully' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer, {scopes: ['cloud_controller.read']}))
            expect(last_response.status).to eql(200)
            expect(parse(last_response.body)).to have_key("system_env_json")
            expect(parse(last_response.body)).to have_key("environment_json")
          end
        end

        context 'when the user is space dev and has service instance bound to application' do
          let!(:service_instance) { ManagedServiceInstance.make(space: app_obj.space) }
          let!(:service_binding) { ServiceBinding.make(app: app_obj, service_instance: service_instance) }

          it 'returns system environment with VCAP_SERVICES'do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer, {scopes: ['cloud_controller.read']}))
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

        it 'returns access denied' do
          get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer))
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
        it 'returns not found' do
          get "/v2/apps/nonexistentappguid/env", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql 404
        end
      end
    end

    describe "staging" do
      context "when app will be staged", isolation: :truncation do
        let(:app_obj) do
          AppFactory.make(:package_hash => "abc", :state => "STOPPED",
                          :droplet_hash => nil, :package_state => "PENDING",
                          :instances => 1)
        end

        let(:stager_response) do
          Dea::AppStagerTask::Response.new("task_streaming_log_url" => "streaming-log-url")
        end

        let(:app_stager_task) do
          double(Dea::AppStagerTask, stage: stager_response)
        end

        before do
          allow(Dea::AppStagerTask).to receive(:new).and_return(app_stager_task)
        end

        it "returns X-App-Staging-Log header with staging log url" do
          put "/v2/apps/#{app_obj.guid}", MultiJson.dump(:state => "STARTED"), json_headers(admin_headers)
          expect(last_response.status).to eq(201)
          expect(last_response.headers["X-App-Staging-Log"]).to eq("streaming-log-url")
        end
      end

      context "when app will not be staged" do
        let(:app_obj) { AppFactory.make(:state => "STOPPED") }

        it "does not add X-App-Staging-Log" do
          put "/v2/apps/#{app_obj.guid}", MultiJson.dump({}), json_headers(admin_headers)
          expect(last_response.status).to eq(201)
          expect(last_response.headers).not_to have_key("X-App-Staging-Log")
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

        expect(Dea::Client).to receive(:update_uris).with(an_instance_of(VCAP::CloudController::App)) do |app|
          expect(app.uris).to include("app.jesse.cloud")
        end

        put @app_url, MultiJson.dump({route_guids: [route.guid]}), json_headers(@headers_for_user)
        expect(last_response.status).to eq(201)
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
        expect(decoded_response["resources"].map { |r|
                 r["metadata"]["guid"]
        }.sort).to eq([bar_route.guid, route.guid].sort)

        expect(Dea::Client).to receive(:update_uris).with(an_instance_of(VCAP::CloudController::App)) do |app|
          expect(app.uris).to include("foo.jesse.cloud")
        end

        put @app_url, MultiJson.dump({route_guids: [route.guid]}), json_headers(@headers_for_user)

        expect(last_response.status).to eq(201)
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = AppFactory.make(:space => @space_a)
        @obj_b = AppFactory.make(:space => @space_b)
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

    describe "Validation messages" do
      let(:space) { Space.make }
      let!(:app_obj) { App.make(space: space) }

      it "returns duplicate app name message correctly" do
        existing_app = App.make(space: space)
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(name: existing_app.name), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(100002)
      end

      it "returns organization quota memory exceeded message correctly" do
        space.organization.quota_definition = QuotaDefinition.make(:memory_limit => 0)
        space.organization.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(100005)
      end

      it "returns space quota memory exceeded message correctly" do
        space.space_quota_definition = SpaceQuotaDefinition.make(:memory_limit => 0)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(310003)
      end

      it "validates space quota memory limit before organization quotas" do
        space.organization.quota_definition = QuotaDefinition.make(:memory_limit => 0)
        space.organization.save(validate: false)
        space.space_quota_definition = SpaceQuotaDefinition.make(:memory_limit => 0)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(310003)
      end

      it "returns memory invalid message correctly" do
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 0), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(100006)
      end

      it "returns instance memory limit exceeded error correctly" do
        space.organization.quota_definition = QuotaDefinition.make(instance_memory_limit: 100)
        space.organization.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(100007)
      end

      it "returns space instance memory limit exceeded error correctly" do
        space.space_quota_definition = SpaceQuotaDefinition.make(instance_memory_limit: 100)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(310004)
      end

      it "validates space quota instance memory limit before organization quotas" do
        space.organization.quota_definition = QuotaDefinition.make(:instance_memory_limit => 100)
        space.organization.save(validate: false)
        space.space_quota_definition = SpaceQuotaDefinition.make(:instance_memory_limit => 100)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(310004)
      end

      it "returns instances invalid message correctly" do
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(instances: -1), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to match /instances less than 1/
        expect(decoded_response["code"]).to eq(100001)
      end

      it "returns state invalid message correctly" do
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(state: 'mississippi'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to match /Invalid app state provided/
        expect(decoded_response["code"]).to eq(100001)
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
