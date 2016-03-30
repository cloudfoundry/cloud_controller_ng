require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::AppsController do
    let(:admin_user) { User.make }
    let(:app_event_repository) { Repositories::Runtime::AppEventRepository.new }
    before { CloudController::DependencyLocator.instance.register(:app_event_repository, app_event_repository) }

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:space_guid) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:diego) }
      it { expect(described_class).to be_queryable_by(:stack_guid) }
    end

    describe 'query by org_guid' do
      let(:app_obj) { AppFactory.make(detected_buildpack: 'buildpack-name', environment_json: { env_var: 'env_val' }) }
      it 'filters apps by org_guid' do
        get "/v2/apps?q=organization_guid:#{app_obj.organization.guid}", {}, json_headers(admin_headers)
        expect(last_response.status).to eq(200)
        expect(decoded_response['resources'][0]['entity']['name']).to eq(app_obj.name)
      end
    end

    describe 'querying by stack guid' do
      let(:stack1) { Stack.make }
      let(:stack2) { Stack.make }
      let!(:app1) { App.make(stack_id: stack1.id) }
      let!(:app2) { App.make(stack_id: stack2.id) }

      it 'filters apps by stack guid' do
        get "/v2/apps?q=stack_guid:#{stack1.guid}", {}, json_headers(admin_headers)
        expect(last_response.status).to eq(200)
        expect(decoded_response['resources'].length).to eq(1)
        expect(decoded_response['resources'][0]['entity']['name']).to eq(app1.name)
      end
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes(
          {
            enable_ssh:              { type: 'bool' },
            buildpack:               { type: 'string' },
            command:                 { type: 'string' },
            console:                 { type: 'bool', default: false },
            debug:                   { type: 'string' },
            disk_quota:              { type: 'integer' },
            environment_json:        { type: 'hash', default: {} },
            health_check_timeout:    { type: 'integer' },
            health_check_type:       { type: 'string', default: 'port' },
            instances:               { type: 'integer', default: 1 },
            memory:                  { type: 'integer' },
            name:                    { type: 'string', required: true },
            production:              { type: 'bool', default: false },
            state:                   { type: 'string', default: 'STOPPED' },
            event_guids:             { type: '[string]' },
            route_guids:             { type: '[string]' },
            space_guid:              { type: 'string', required: true },
            stack_guid:              { type: 'string' },
            diego:                   { type: 'bool' },
            docker_image:            { type: 'string', required: false },
            docker_credentials_json: { type: 'hash', default: {} },
            ports:                   { type: '[integer]', default: nil }
          })
      end

      it do
        expect(described_class).to have_updatable_attributes(
          {
            enable_ssh:              { type: 'bool' },
            buildpack:               { type: 'string' },
            command:                 { type: 'string' },
            console:                 { type: 'bool' },
            debug:                   { type: 'string' },
            disk_quota:              { type: 'integer' },
            environment_json:        { type: 'hash' },
            health_check_timeout:    { type: 'integer' },
            health_check_type:       { type: 'string' },
            instances:               { type: 'integer' },
            memory:                  { type: 'integer' },
            name:                    { type: 'string' },
            production:              { type: 'bool' },
            state:                   { type: 'string' },
            event_guids:             { type: '[string]' },
            route_guids:             { type: '[string]' },
            service_binding_guids:   { type: '[string]' },
            space_guid:              { type: 'string' },
            stack_guid:              { type: 'string' },
            diego:                   { type: 'bool' },
            docker_image:            { type: 'string' },
            docker_credentials_json: { type: 'hash' },
            ports:                   { type: '[integer]' }

          })
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes(
          {
            events:           [:get, :put, :delete],
            service_bindings: [:get, :put, :delete],
            routes:           [:get, :put, :delete],
            route_mappings:   [:get],
          })
      end

      describe 'events associations (via AppEvents)' do
        it 'does not return events with inline-relations-depth=0' do
          app = App.make
          get "/v2/apps/#{app.guid}?inline-relations-depth=0", {}, json_headers(admin_headers)
          expect(entity).to have_key('events_url')
          expect(entity).to_not have_key('events')
        end

        it 'does not return events with inline-relations-depth=1 since app_events dataset is relatively expensive to query' do
          app = App.make
          get "/v2/apps/#{app.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)
          expect(entity).to have_key('events_url')
          expect(entity).to_not have_key('events')
        end
      end
    end

    describe 'create app' do
      let(:space) { Space.make }
      let(:space_guid) { space.guid.to_s }
      let(:initial_hash) do
        {
          name: 'maria',
          space_guid: space_guid
        }
      end

      let(:decoded_response) { MultiJson.load(last_response.body) }

      describe 'events' do
        it 'records app create' do
          expected_attrs = AppsController::CreateMessage.decode(initial_hash.to_json).extract(stringify_keys: true)
          allow(app_event_repository).to receive(:record_app_create).and_call_original

          post '/v2/apps', MultiJson.dump(initial_hash), json_headers(admin_headers_for(admin_user))

          app = App.last
          expect(app_event_repository).to have_received(:record_app_create).with(app, app.space, admin_user.guid, SecurityContext.current_user_email, expected_attrs)
        end
      end

      context 'when the org is suspended' do
        before do
          space.organization.update(status: 'suspended')
        end

        it 'does not allow user to create new app (spot check)' do
          post '/v2/apps', MultiJson.dump(initial_hash), json_headers(headers_for(make_developer_for_space(space)))
          expect(last_response.status).to eq(403)
        end
      end

      context 'when allow_ssh is enabled globally' do
        before do
          allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
          allow(VCAP::CloudController::Config.config).to receive(:[]).with(:allow_app_ssh_access).and_return true
        end

        context 'when allow_ssh is enabled on the space' do
          before do
            space.allow_ssh = true
            space.save
          end

          it 'allows enable_ssh to be set to true' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true)), json_headers(admin_headers)
            expect(last_response.status).to eq(201)
          end

          it 'allows enable_ssh to be set to false' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false)), json_headers(admin_headers)
            expect(last_response.status).to eq(201)
          end
        end

        context 'when allow_ssh is disabled on the space' do
          before do
            space.allow_ssh = false
            space.save
          end

          it 'allows enable_ssh to be set to false' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false)), json_headers(admin_headers)
            expect(last_response.status).to eq(201)
          end

          context 'and the user is an admin' do
            it 'allows enable_ssh to be set to true' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true)), json_headers(admin_headers)
              expect(last_response.status).to eq(201)
            end
          end

          context 'and the user is not an admin' do
            let(:nonadmin_user) { VCAP::CloudController::User.make(active: true) }

            it 'errors when attempting to set enable_ssh to true' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true)), json_headers(headers_for(nonadmin_user))
              expect(last_response.status).to eq(400)
            end
          end
        end
      end

      context 'when allow_ssh is disabled globally' do
        before do
          allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
          allow(VCAP::CloudController::Config.config).to receive(:[]).with(:allow_app_ssh_access).and_return false
        end

        context 'when allow_ssh is enabled on the space' do
          before do
            space.allow_ssh = true
            space.save
          end

          it 'errors when attempting to set enable_ssh to true' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true)), json_headers(admin_headers)
            expect(last_response.status).to eq(400)
          end

          it 'allows enable_ssh to be set to false' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false)), json_headers(admin_headers)
            expect(last_response.status).to eq(201)
          end
        end

        context 'when allow_ssh is disabled on the space' do
          before do
            space.allow_ssh = false
            space.save
          end

          it 'errors when attempting to set enable_ssh to true' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true)), json_headers(admin_headers)
            expect(last_response.status).to eq(400)
          end

          it 'allows enable_ssh to be set to false' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false)), json_headers(admin_headers)
            expect(last_response.status).to eq(201)
          end
        end

        context 'when diego is set to true' do
          context 'when no custom ports are specified' do
            it 'sets the ports to 8080' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: true)), json_headers(admin_headers)
              expect(last_response.status).to eq(201)
              expect(decoded_response['entity']['ports']).to match([8080])
              expect(decoded_response['entity']['diego']).to be true
            end
          end

          context 'when custom ports are specified' do
            it 'sets the ports to as specified in the request' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: true, ports: [9090, 5222])), json_headers(admin_headers)
              expect(last_response.status).to eq(201)
              expect(decoded_response['entity']['ports']).to match([9090, 5222])
              expect(decoded_response['entity']['diego']).to be true
            end
          end

          context 'when the custom port is not in the valid range 1024-65535' do
            it 'return an error' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: true, ports: [9090, 500])), json_headers(admin_headers)
              expect(last_response.status).to eq(400)
              expect(decoded_response['description']).to include('Ports must be in the 1024-65535.')
            end
          end
        end

        context 'when diego is set to false' do
          context 'when no custom ports are specified' do
            it 'sets the ports to nil' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: false)), json_headers(admin_headers)
              expect(last_response.status).to eq(201)
              expect(decoded_response['entity']['ports']).to be nil
              expect(decoded_response['entity']['diego']).to be false

              warning = last_response.headers['X-Cf-Warnings']
              expect(warning).to be_nil
            end
          end

          context 'when custom ports are specified' do
            it 'returns an error' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: false, ports: [9090, 5222])), json_headers(admin_headers)
              expect(last_response.status).to eq(400)
              expect(decoded_response['description']).to include('Custom app ports supported for Diego only. Enable Diego for the app or remove custom app ports.')
            end
          end
        end
      end
    end

    describe 'docker image credentials' do
      let(:space) { Space.make }
      let(:space_guid) { space.guid.to_s }
      let(:initial_hash) do
        {
          name: 'maria',
          space_guid: space_guid
        }
      end
      let(:decoded_response) { MultiJson.load(last_response.body) }

      let(:login_server) { 'https://index.docker.io/v1' }
      let(:user) { 'user' }
      let(:password) { 'password' }
      let(:email) { 'email@example.com' }
      let(:docker_credentials) do
        {
          docker_login_server: login_server,
          docker_user: user,
          docker_password: password,
          docker_email: email
        }
      end
      let(:body) do
        MultiJson.dump(initial_hash.merge(docker_credentials_json: docker_credentials))
      end

      let(:user_headers) { json_headers(admin_headers) }
      let(:redacted_message) { { 'redacted_message' => '[PRIVATE DATA HIDDEN]' } }

      def create_app
        post '/v2/apps', body, user_headers
        expect(last_response).to have_status_code(201)
        decoded_response['metadata']['guid']
      end

      def read_app
        app_guid = create_app
        get "/v2/apps/#{app_guid}", '{}', user_headers
        expect(last_response).to have_status_code(200)
      end

      def update_app
        app_guid = create_app
        put "/v2/apps/#{app_guid}", body, user_headers
        expect(last_response).to have_status_code(201)
      end

      context 'create app' do
        context 'by admin' do
          it 'redacts the credentials' do
            create_app
          end
        end

        context 'by developer' do
          let(:user_headers) { json_headers(headers_for(make_developer_for_space(space))) }

          it 'redacts the credentials' do
            create_app
            expect(decoded_response['entity']['docker_credentials_json']).to eq redacted_message
          end
        end
      end

      context 'read app' do
        context 'by admin' do
          it 'redacts the credentials' do
            read_app
            expect(decoded_response['entity']['docker_credentials_json']).to eq redacted_message
          end
        end

        context 'by developer' do
          let(:user_headers) { json_headers(headers_for(make_developer_for_space(space))) }

          it 'redacts the credentials' do
            read_app
            expect(decoded_response['entity']['docker_credentials_json']).to eq redacted_message
          end
        end
      end

      context 'update app' do
        context 'by admin' do
          it 'redacts the credentials' do
            update_app
            expect(decoded_response['entity']['docker_credentials_json']).to eq redacted_message
          end
        end

        context 'by developer' do
          let(:user_headers) { json_headers(headers_for(make_developer_for_space(space))) }

          it 'redacts the credentials' do
            update_app
            expect(decoded_response['entity']['docker_credentials_json']).to eq redacted_message
          end
        end
      end
    end

    describe 'update app' do
      let(:update_hash) { {} }

      let(:app_obj) { AppFactory.make(instances: 1) }
      let(:developer) { make_developer_for_space(app_obj.space) }

      def update_app
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(update_hash), json_headers(admin_headers)
      end

      describe 'app_scaling feature flag' do
        context 'when the flag is enabled' do
          before { FeatureFlag.make(name: 'app_scaling', enabled: true) }

          it 'allows updating memory' do
            put "/v2/apps/#{app_obj.guid}", '{ "memory": 2 }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(201)
          end
        end

        context 'when the flag is disabled' do
          before { FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

          it 'fails with the proper error code and message' do
            put "/v2/apps/#{app_obj.guid}", '{ "memory": 2 }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(403)
            expect(decoded_response['error_code']).to match(/FeatureDisabled/)
            expect(decoded_response['description']).to match(/app_scaling/)
          end
        end
      end

      context 'switch from dea to diego' do
        let(:app_obj) { AppFactory.make(instances: 1, diego: false) }
        let(:developer) { make_developer_for_space(app_obj.space) }
        let(:route) { Route.make(space: app_obj.space) }
        let(:route_mapping) { RouteMapping.make(app_id: app_obj.id, route_id: route.id) }

        context 'when user does not specify any ports' do
          it 'sets ports to 8080' do
            expect(route_mapping.app_port).to be_nil
            put "/v2/apps/#{app_obj.guid}", '{ "diego": true }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['ports']).to match([8080])
            expect(decoded_response['entity']['diego']).to be true
            expect(route_mapping.reload.app_port).to eq(8080)
          end
        end

        context 'when user specifies ports' do
          it 'sets ports to user specified values' do
            expect(route_mapping.app_port).to be_nil
            put "/v2/apps/#{app_obj.guid}", '{ "diego": true, "ports": [9090,5222] }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['ports']).to match([9090, 5222])
            expect(decoded_response['entity']['diego']).to be true
            expect(route_mapping.reload.app_port).to eq(9090)
          end
        end
      end

      context 'switch from diego to dea' do
        let(:app_obj) { AppFactory.make(instances: 1, diego: true, ports: [8080, 5222]) }
        it 'updates the backend of the app and returns 201 with warning' do
          put "/v2/apps/#{app_obj.guid}", '{ "diego": false}', json_headers(headers_for(developer))
          expect(last_response).to have_status_code(201)
          expect(decoded_response['entity']['ports']).to be nil
          expect(decoded_response['entity']['diego']).to be false
          warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])
          expect(warning).to include('App ports have changed but are unknown. The app should now listen on the port specified by environment variable PORT')
        end

        context 'when custom ports are specified as part of update' do
          it 'returns error indicating custom ports need to be removed' do
            put "/v2/apps/#{app_obj.guid}", '{ "diego": false, "ports":[9090] }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to include('Custom app ports supported for Diego only. Enable Diego for the app or remove custom app ports.')
          end
        end

        context 'when the app has existing custom ports' do
          let(:app_obj) { AppFactory.make(instances: 1, diego: true, ports: [9090, 5222]) }
          let(:route) { Route.make(space: app_obj.space) }
          let(:route_mapping) { RouteMapping.make(app_id: app_obj.id, route_id: route.id) }

          it 'removes the app ports from the route mapping' do
            put "/v2/apps/#{app_obj.guid}", '{ "diego": false }', json_headers(headers_for(developer))
            expect(last_response).to have_status_code(201)
            expect(decoded_response['entity']['ports']).to be nil
            expect(decoded_response['entity']['diego']).to be false
          end
        end

        context 'when the app is mapped to multiple ports' do
          let(:app_obj) { AppFactory.make(instances: 1, diego: true, ports: [9090, 5222]) }
          let(:route) { Route.make(space: app_obj.space) }
          let!(:route_mapping_1) { RouteMapping.make(app: app_obj, route: route, app_port: 9090) }
          let!(:route_mapping_2) { RouteMapping.make(app: app_obj, route: route, app_port: 5222) }
          let(:error_message) do
            'The app has routes mapped to multiple ports. ' \
            'Multiple ports are supported for Diego only. ' \
            'Please unmap routes from all but one app port. ' \
            'Multiple routes can be mapped to the same port if desired.'
          end

          it 'returns an error' do
            put "/v2/apps/#{app_obj.guid}", '{ "diego": false }', json_headers(headers_for(developer))
            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include(error_message)
          end
        end
      end

      context 'when app is dea app' do
        context 'when custom ports are specified' do
          it 'returns error indicating custom ports need to be removed' do
            put "/v2/apps/#{app_obj.guid}", '{ "ports": [9090] }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to include('Custom app ports supported for Diego only. Enable Diego for the app or remove custom app ports.')
          end
        end
      end

      context 'when app is diego app' do
        let(:app_obj) { AppFactory.make(instances: 1, diego: true, ports: [9090, 5222]) }

        it 'sets ports to user specified values' do
          put "/v2/apps/#{app_obj.guid}", '{ "ports": [1883,5222] }', json_headers(headers_for(developer))
          expect(last_response.status).to eq(201)
          expect(decoded_response['entity']['ports']).to match([1883, 5222])
          expect(decoded_response['entity']['diego']).to be true
        end

        context 'when not updating ports' do
          it 'should keep previously specified custom ports' do
            put "/v2/apps/#{app_obj.guid}", '{ "instances":2 }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['ports']).to match([9090, 5222])
            expect(decoded_response['entity']['diego']).to be true
          end
        end

        context 'when the user sets ports to an empty array' do
          it 'should keep previously specified custom ports' do
            put "/v2/apps/#{app_obj.guid}", '{ "ports":[] }', json_headers(headers_for(developer))
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['ports']).to match([9090, 5222])
            expect(decoded_response['entity']['diego']).to be true
          end
        end

        context 'when updating an app with existing route mapping' do
          let(:route) { Route.make(space: app_obj.space) }
          let!(:route_mapping) { RouteMapping.make(id: 1, app_id: app_obj.id, route_id: route.id, app_port: 9090) }
          let!(:route_mapping2) { RouteMapping.make(id: 2, app_id: app_obj.id, route_id: route.id, app_port: 5222) }

          context 'when new app ports contains all existing route port mappings' do
            it 'updates the ports' do
              put "/v2/apps/#{app_obj.guid}", '{ "ports":[9090, 5222, 1234] }', json_headers(headers_for(developer))
              expect(last_response.status).to eq(201)
              expect(decoded_response['entity']['ports']).to match([9090, 5222, 1234])
            end
          end

          context 'when new app ports partially contains existing route port mappings' do
            it 'returns 400' do
              put "/v2/apps/#{app_obj.guid}", '{ "ports":[5222, 1234] }', json_headers(headers_for(developer))
              expect(last_response.status).to eq(400)
              expect(decoded_response['description']).to include('App ports ports may not be removed while routes are mapped to them.')
            end
          end

          context 'when new app ports do not contain existing route mapping port' do
            it 'returns 400' do
              put "/v2/apps/#{app_obj.guid}", '{ "ports":[1234] }', json_headers(headers_for(developer))
              expect(last_response.status).to eq(400)
              expect(decoded_response['description']).to include('App ports ports may not be removed while routes are mapped to them.')
            end
          end
        end
      end

      describe 'events' do
        let(:update_hash) { { instances: 2, foo: 'foo_value' } }

        context 'when the update succeeds' do
          it 'records app update with whitelisted attributes' do
            allow(app_event_repository).to receive(:record_app_update).and_call_original

            expect(app_event_repository).to receive(:record_app_update) do |recorded_app, recorded_space, user_guid, user_name, attributes|
              expect(recorded_app.guid).to eq(app_obj.guid)
              expect(recorded_app.instances).to eq(2)
              expect(user_guid).to eq(admin_user.guid)
              expect(user_name).to eq(SecurityContext.current_user_email)
              expect(attributes).to eq({ 'instances' => 2 })
            end

            update_app
          end
        end

        context 'when the update fails' do
          before do
            allow_any_instance_of(App).to receive(:update_from_hash).and_raise('Error saving')
            allow(app_event_repository).to receive(:record_app_update)
          end

          it 'does not record app update' do
            update_app

            expect(app_event_repository).to_not have_received(:record_app_update)
            expect(last_response.status).to eq(500)
          end
        end
      end

      context 'when associating with route' do
        let(:domain) { SharedDomain.make(name: 'tcp.com', router_group_guid: 'guid_1') }
        let(:route) { Route.make(space: app_obj.space, domain: domain, port: 9090, host: '') }

        it 'allows updating app' do
          put "/v2/apps/#{app_obj.guid}/routes/#{route.guid}", nil, json_headers(admin_headers)

          expect(last_response).to have_status_code(201)
          expect(app_obj.reload.routes.first).to eq(route)
        end

        context 'when routing api is not enabled' do
          before do
            TestConfig.override(routing_api: nil)
          end

          it 'returns 403' do
            put "/v2/apps/#{app_obj.guid}/routes/#{route.guid}", nil, json_headers(admin_headers)
            expect(last_response).to have_status_code(403)
            expect(decoded_response['description']).to include('Support for TCP routing is disabled')
          end
        end
      end
    end

    describe 'delete an app' do
      let(:app_obj) { AppFactory.make }

      let(:decoded_response) { MultiJson.load(last_response.body) }

      def delete_app
        delete "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers_for(admin_user))
      end

      it 'deletes the app' do
        delete_app
        expect(last_response.status).to eq(204)
        expect(App.filter(id: app_obj.id)).to be_empty
      end

      context 'non recursive deletion' do
        context 'with NON-empty service_binding association' do
          let!(:svc_instance) { ManagedServiceInstance.make(space: app_obj.space) }
          let!(:service_binding) { ServiceBinding.make(app: app_obj, service_instance: svc_instance) }
          let(:guid_pattern) { '[[:alnum:]-]+' }

          before do
            service_broker = svc_instance.service.service_broker
            uri = URI(service_broker.broker_url)
            broker_url = uri.host + uri.path
            broker_auth = "#{service_broker.auth_username}:#{service_broker.auth_password}"
            stub_request(
              :delete,
              %r{https://#{broker_auth}@#{broker_url}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}).
              to_return(status: 200, body: '{}')
          end

          it 'should raise an error' do
            delete_app

            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to match(/service_bindings/i)
          end

          it 'should succeed on a recursive delete' do
            delete "/v2/apps/#{app_obj.guid}?recursive=true", {}, json_headers(admin_headers)

            expect(last_response).to have_status_code(204)
          end
        end
      end

      describe 'events' do
        it 'records an app delete-request' do
          allow(app_event_repository).to receive(:record_app_delete_request).and_call_original

          delete_app

          expect(app_event_repository).to have_received(:record_app_delete_request).with(app_obj, app_obj.space, admin_user.guid, SecurityContext.current_user_email, false)
        end

        it 'records the recursive query parameter when recursive' do
          allow(app_event_repository).to receive(:record_app_delete_request).and_call_original

          delete "/v2/apps/#{app_obj.guid}?recursive=true", {}, json_headers(admin_headers_for(admin_user))

          expect(app_event_repository).to have_received(:record_app_delete_request).with(app_obj, app_obj.space, admin_user.guid, SecurityContext.current_user_email, true)
        end

        it 'does not record when the destroy fails' do
          allow_any_instance_of(App).to receive(:destroy).and_raise('Error saving')
          allow(app_event_repository).to receive(:record_app_delete_request).and_call_original

          delete_app
          expect(app_event_repository).not_to have_received(:record_app_delete_request)
        end
      end
    end

    describe 'route mapping' do
      let!(:app_obj) { AppFactory.make(instances: 1, diego: true) }
      let!(:developer) { make_developer_for_space(app_obj.space) }
      let!(:route) { Route.make(space: app_obj.space) }
      let!(:route_mapping) { RouteMapping.make(app_id: app_obj.id, route_id: route.id) }

      context 'GET' do
        it 'returns the route mapping' do
          get "/v2/apps/#{app_obj.guid}/route_mappings", '{}', json_headers(headers_for(developer))
          expect(last_response.status).to eql(200)
          parsed_body = parse(last_response.body)
          expect(parsed_body['resources'].first['entity']['route_guid']).to eq(route.guid)
          expect(parsed_body['resources'].first['entity']['app_guid']).to eq(app_obj.guid)
        end
      end

      context 'POST' do
        it 'returns 404' do
          post "/v2/apps/#{app_obj.guid}/route_mappings", '{}', json_headers(headers_for(developer))
          expect(last_response.status).to eql(404)
        end
      end

      context 'PUT' do
        it 'returns 404' do
          put "/v2/apps/#{app_obj.guid}/route_mappings/#{route_mapping.guid}", '{}', json_headers(headers_for(developer))
          expect(last_response.status).to eql(404)
        end
      end

      context 'DELETE' do
        it 'returns 404' do
          delete "/v2/apps/#{app_obj.guid}/route_mappings/#{route_mapping.guid}", '', json_headers(headers_for(developer))
          expect(last_response.status).to eql(404)
        end
      end
    end

    describe "read an app's env" do
      let(:space)     { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:auditor) { make_auditor_for_space(space) }
      let(:app_obj) { AppFactory.make(detected_buildpack: 'buildpack-name') }
      let(:decoded_response) { MultiJson.load(last_response.body) }

      context 'when the user is a member of the space this app exists in' do
        let(:app_obj) { AppFactory.make(detected_buildpack: 'buildpack-name', space: space) }

        context 'when the user is not a space developer' do
          it 'returns a JSON payload indicating they do not have permission to manage this instance' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(auditor, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('You are not authorized to perform the requested action')
          end
        end

        context 'when the user has only the cloud_controller.read scope' do
          it 'returns successfully' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(200)
            parsed_body = parse(last_response.body)
            expect(parsed_body).to have_key('staging_env_json')
            expect(parsed_body).to have_key('running_env_json')
            expect(parsed_body).to have_key('environment_json')
            expect(parsed_body).to have_key('system_env_json')
            expect(parsed_body).to have_key('application_env_json')
          end
        end

        context 'environment variable' do
          context 'when there is no v3 app associated' do
            it 'returns v2 application environment with VCAP_APPLICATION' do
              get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer, { scopes: ['cloud_controller.read'] }))
              expect(last_response.status).to eql(200)

              expect(decoded_response['application_env_json']).to have_key('VCAP_APPLICATION')
              expect(decoded_response['application_env_json']).to match({
                  'VCAP_APPLICATION' => {
                    'limits' => {
                      'mem'  => app_obj.memory,
                      'disk' => app_obj.disk_quota,
                      'fds'  => 16384
                    },
                    'application_id'      => app_obj.guid,
                    'application_name'    => app_obj.name,
                    'name'                => app_obj.name,
                    'application_uris'    => [],
                    'uris'                => [],
                    'application_version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                    'version'             => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                    'space_name'          => app_obj.space.name,
                    'space_id'            => app_obj.space.guid,
                    'users'               => nil
                  }
              })
            end
          end

          context 'when a v3 app is associated' do
            let!(:app_model) { AppModel.make(name: 'v3-parent-app') }
            let!(:process) { AppFactory.make(memory: 259, disk_quota: 799, file_descriptors: 1234, name: 'process-name') }

            it 'returns appenvironment with VCAP_APPLICATION with v3 app name' do
              app_model.add_process(process)

              get "/v2/apps/#{process.guid}/env", '{}', admin_headers
              expect(last_response.status).to eql(200)

              expect(decoded_response['application_env_json']).to have_key('VCAP_APPLICATION')
              expect(decoded_response['application_env_json']).to match({
                  'VCAP_APPLICATION' => {
                  'limits' => {
                    'mem' => 259,
                    'disk' => 799,
                    'fds' => 1234,
                  },
                  'application_id' => process.guid,
                  'application_version' => process.version,
                  'application_name' => app_model.name,
                  'application_uris' => process.uris,
                  'version' => process.version,
                  'name' => process.name,
                  'space_name' => process.space.name,
                  'space_id' => process.space.guid,
                  'uris' => process.uris,
                  'users' => nil
                }
              })
            end
          end
        end

        context 'when the user is space dev and has service instance bound to application' do
          let!(:service_instance) { ManagedServiceInstance.make(space: app_obj.space) }
          let!(:service_binding) { ServiceBinding.make(app: app_obj, service_instance: service_instance) }

          it 'returns system environment with VCAP_SERVICES' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(200)

            expect(decoded_response['system_env_json'].size).to eq(1)
            expect(decoded_response['system_env_json']).to have_key('VCAP_SERVICES')
          end
        end

        context 'when the staging env variable group is set' do
          before do
            staging_group = EnvironmentVariableGroup.staging
            staging_group.environment_json = { POTATO: 'delicious' }
            staging_group.save
          end

          it 'returns staging_env_json with those variables' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(200)

            expect(decoded_response['staging_env_json'].size).to eq(1)
            expect(decoded_response['staging_env_json']).to have_key('POTATO')
            expect(decoded_response['staging_env_json']['POTATO']).to eq('delicious')
          end
        end

        context 'when the running env variable group is set' do
          before do
            running_group = EnvironmentVariableGroup.running
            running_group.environment_json = { PIE: 'sweet' }
            running_group.save
          end

          it 'returns staging_env_json with those variables' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(200)

            expect(decoded_response['running_env_json'].size).to eq(1)
            expect(decoded_response['running_env_json']).to have_key('PIE')
            expect(decoded_response['running_env_json']['PIE']).to eq('sweet')
          end
        end

        context 'when the user does not have the necessary scope' do
          it 'returns InvalidAuthToken' do
            get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer, { scopes: ['cloud_controller.write'] }))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('Your token lacks the necessary scopes to access this resource.')
          end
        end
      end

      context 'when the user reads environment variables from the app endpoint using inline-relations-depth=2' do
        let!(:test_environment_json) { { 'environ_key' => 'value' } }
        let!(:app_obj) do
          AppFactory.make(
            detected_buildpack: 'buildpack-name',
            space:              space,
            environment_json:   test_environment_json
          )
        end
        let!(:service_instance) { ManagedServiceInstance.make(space: app_obj.space) }
        let!(:service_binding) { ServiceBinding.make(app: app_obj, service_instance: service_instance) }

        context 'when the user is a space developer' do
          it 'returns non-redacted environment values' do
            get '/v2/apps?inline-relations-depth=2', {}, json_headers(headers_for(developer, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(200)

            expect(decoded_response['resources'].first['entity']['environment_json']).to eq(test_environment_json)
            expect(decoded_response).not_to have_key('system_env_json')
          end
        end

        context 'when the user is not a space developer' do
          it 'returns redacted values' do
            get '/v2/apps?inline-relations-depth=2', {}, json_headers(headers_for(auditor, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(200)

            expect(decoded_response['resources'].first['entity']['environment_json']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(decoded_response).not_to have_key('system_env_json')
          end
        end
      end

      context 'when the user is NOT a member of the space this instance exists in' do
        let(:app_obj) { AppFactory.make(detected_buildpack: 'buildpack-name') }

        it 'returns access denied' do
          get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(developer))
          expect(last_response.status).to eql(403)
        end
      end

      context 'when the user has not authenticated with Cloud Controller' do
        let(:instance)  { ManagedServiceInstance.make }
        let(:developer) { nil }

        it 'returns an error saying that the user is not authenticated' do
          get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer))
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the app does not exist' do
        it 'returns not found' do
          get '/v2/apps/nonexistentappguid/env', {}, json_headers(headers_for(developer))
          expect(last_response.status).to eql 404
        end
      end

      context 'when the space_developer_env_var_visibility feature flag is disabled' do
        let(:app_obj) { AppFactory.make(detected_buildpack: 'buildpack-name', space: space) }

        before do
          VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for non-admins' do
          get "/v2/apps/#{app_obj.guid}/env", {}, json_headers(headers_for(developer))

          expect(last_response.status).to eq(403)
          expect(last_response.body).to include('FeatureDisabled')
          expect(last_response.body).to include('space_developer_env_var_visibility')
        end

        it 'succeeds for admins' do
          get "/v2/apps/#{app_obj.guid}/env", {}, admin_headers

          expect(last_response.status).to eq(200)
        end

        context 'when the user is not a space developer' do
          it 'indicates they do not have permission rather than that the feature flag is disabled' do
            get "/v2/apps/#{app_obj.guid}/env", '{}', json_headers(headers_for(auditor, { scopes: ['cloud_controller.read'] }))
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('You are not authorized to perform the requested action')
          end
        end
      end
    end

    describe 'staging' do
      before { Buildpack.make }

      context 'when app will be staged', isolation: :truncation do
        let(:app_obj) do
          AppFactory.make(package_hash: 'abc', state: 'STOPPED',
                          droplet_hash: nil, package_state: 'PENDING',
                          instances: 1)
        end

        let(:stager_response) do
          Dea::StagingResponse.new('task_streaming_log_url' => 'streaming-log-url')
        end

        let(:app_stager_task) do
          double(Dea::AppStagerTask, stage: stager_response)
        end

        before do
          allow(Dea::AppStagerTask).to receive(:new).and_return(app_stager_task)
        end

        it 'returns X-App-Staging-Log header with staging log url' do
          put "/v2/apps/#{app_obj.guid}", MultiJson.dump(state: 'STARTED'), json_headers(admin_headers)
          expect(last_response.status).to eq(201)
          expect(last_response.headers['X-App-Staging-Log']).to eq('streaming-log-url')
        end
      end

      context 'when app will not be staged' do
        let(:app_obj) { AppFactory.make(state: 'STOPPED') }

        it 'does not add X-App-Staging-Log' do
          put "/v2/apps/#{app_obj.guid}", MultiJson.dump({}), json_headers(admin_headers)
          expect(last_response.status).to eq(201)
          expect(last_response.headers).not_to have_key('X-App-Staging-Log')
        end
      end
    end

    describe 'downloading the droplet' do
      let(:app_obj) { AppFactory.make }
      let(:blob) { instance_double(CloudController::Blobstore::FogBlob) }

      before do
        allow(blob).to receive(:public_download_url).and_return('http://example.com/somewhere/else')
        allow_any_instance_of(CloudController::Blobstore::Client).to receive(:blob).and_return(blob)
      end

      it 'should let the user download the droplet' do
        get "/v2/apps/#{app_obj.guid}/droplet/download", MultiJson.dump({}), json_headers(admin_headers)
        expect(last_response).to be_redirect
        expect(last_response.header['Location']).to eq('http://example.com/somewhere/else')
      end

      it 'should return an error for non-existent apps' do
        get '/v2/apps/bad/droplet/download', MultiJson.dump({}), json_headers(admin_headers)
        expect(last_response.status).to eq(404)
      end

      it 'should return an error for an app without a droplet' do
        app_obj.droplet_hash = nil
        app_obj.save

        get "/v2/apps/#{app_obj.guid}/droplet/download", MultiJson.dump({}), json_headers(admin_headers)
        expect(last_response.status).to eq(404)
      end
    end

    describe 'on route change' do
      let(:space) { Space.make }
      let(:domain) do
        PrivateDomain.make(name: 'jesse.cloud', owning_organization: space.organization)
      end

      before do
        user = make_developer_for_space(space)
        # keeping the headers here so that it doesn't reset the global config...
        @headers_for_user = headers_for(user)
        @app = AppFactory.make(
          space: space,
          state: 'STARTED',
          package_hash: 'abc',
          droplet_hash: 'def',
          package_state: 'STAGED',
        )
        @app_url = "/v2/apps/#{@app.guid}"
      end

      it 'tells the dea client to update when we add one url through PUT /v2/apps/:guid' do
        route = domain.add_route(
          host: 'app',
          space: space,
        )

        expect(Dea::Client).to receive(:update_uris).with(an_instance_of(VCAP::CloudController::App)) do |app|
          expect(app.uris).to include('app.jesse.cloud')
        end

        put @app_url, MultiJson.dump({ route_guids: [route.guid] }), json_headers(@headers_for_user)
        expect(last_response.status).to eq(201)
      end

      context 'with Docker app' do
        let(:route) { domain.add_route(host: 'app', space: space) }
        let(:pre_mapped_route) { domain.add_route(host: 'pre_mapped_route', space: space) }
        let(:docker_app) do
          AppFactory.make(
            space: space,
            state: 'STARTED',
            package_hash: 'abc',
            droplet_hash: 'def',
            package_state: 'STAGED',
            diego: true,
            docker_image: 'some-image',
          )
        end

        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
          put "/v2/apps/#{docker_app.guid}/routes/#{pre_mapped_route.guid}", {}, json_headers(@headers_for_user)
        end

        context 'when Docker is disabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          end

          context 'and a route is mapped' do
            before do
              put "/v2/apps/#{docker_app.guid}/routes/#{route.guid}", nil, json_headers(@headers_for_user)
            end

            it 'succeeds' do
              expect(last_response.status).to eq(201)
            end
          end

          context 'and a previously mapped route is unmapped' do
            before do
              delete "/v2/apps/#{docker_app.guid}/routes/#{pre_mapped_route.guid}", nil, json_headers(@headers_for_user)
            end

            it 'succeeds' do
              expect(last_response.status).to eq(204)
            end
          end
        end
      end

      it 'tells the dea client to update when we remove a url through PUT /v2/apps/:guid' do
        bar_route = @app.add_route(
          host: 'bar',
          space: space,
          domain: domain,
        )
        route = @app.add_route(
          host: 'foo',
          space: space,
          domain: domain,
        )
        get "#{@app_url}/routes", {}, @headers_for_user
        expect(decoded_response['resources'].map { |r|
          r['metadata']['guid']
        }.sort).to eq([bar_route.guid, route.guid].sort)

        expect(Dea::Client).to receive(:update_uris).with(an_instance_of(VCAP::CloudController::App)) do |app|
          expect(app.uris).to include('foo.jesse.cloud')
        end

        put @app_url, MultiJson.dump({ route_guids: [route.guid] }), json_headers(@headers_for_user)

        expect(last_response.status).to eq(201)
      end
    end

    describe 'on route bind' do
      context 'with a non-Diego app' do
        let(:space) { route.space }
        let(:app_obj) { AppFactory.make(diego: false, space: space, state: 'STARTED') }
        let(:user) { make_developer_for_space(space) }
        let(:route_binding) { RouteBinding.make }
        let(:service_instance) { route_binding.service_instance }
        let(:route) { route_binding.route }

        context 'and the route is already bound to a routing service' do
          let(:decoded_response) { MultiJson.load(last_response.body) }

          it 'fails to change the route' do
            put "/v2/apps/#{app_obj.guid}/routes/#{route.guid}", nil, json_headers(headers_for(user))

            expect(decoded_response['description']).to match(/Invalid relation: The requested route relation is invalid: .* - Route services are only supported for apps on Diego/)
            expect(last_response.status).to eq(400)
          end
        end
      end
    end

    describe 'on instance number change' do
      before do
        FeatureFlag.create(name: 'diego_docker', enabled: true)
      end

      context 'when docker is disabled' do
        let(:space) { Space.make }
        let!(:started_app) do
          App.make(space: space, state: 'STARTED', package_hash: 'made-up-package-hash', docker_image: 'docker-image')
        end

        before do
          FeatureFlag.find(name: 'diego_docker').update(enabled: false)
        end

        it 'does not return docker disabled message' do
          put "/v2/apps/#{started_app.guid}", MultiJson.dump(instances: 2), json_headers(admin_headers)

          expect(last_response.status).to eq(201)
        end
      end
    end

    describe 'on state change' do
      before do
        FeatureFlag.create(name: 'diego_docker', enabled: true)
      end

      context 'when docker is disabled' do
        let(:space) { Space.make }
        let!(:stopped_app) { App.make(space: space, state: 'STOPPED', package_hash: 'made-up-package-hash', docker_image: 'docker-image') }
        let!(:started_app) do
          App.make(space: space, state: 'STARTED', package_hash: 'made-up-package-hash', docker_image: 'docker-image')
        end

        before do
          FeatureFlag.find(name: 'diego_docker').update(enabled: false)
        end

        it 'returns docker disabled message on start' do
          put "/v2/apps/#{stopped_app.guid}", MultiJson.dump(state: 'STARTED'), json_headers(admin_headers)

          expect(last_response.status).to eq(400)
          expect(last_response.body).to match /Docker support has not been enabled/
          expect(decoded_response['code']).to eq(320003)
        end

        it 'does not return docker disabled message on stop' do
          put "/v2/apps/#{started_app.guid}", MultiJson.dump(state: 'STOPPED'), json_headers(admin_headers)

          expect(last_response.status).to eq(201)
        end
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @obj_a = AppFactory.make(space: @space_a)
        @obj_b = AppFactory.make(space: @space_b)
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'permission enumeration', 'OrgManager',
            name: 'app',
            path: '/v2/apps',
            enumerate: 1
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples 'permission enumeration', 'OrgUser',
            name: 'app',
            path: '/v2/apps',
            enumerate: 0
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples 'permission enumeration', 'BillingManager',
            name: 'app',
            path: '/v2/apps',
            enumerate: 0
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples 'permission enumeration', 'Auditor',
            name: 'app',
            path: '/v2/apps',
            enumerate: 0
        end
      end

      describe 'App Space Level Permissions' do
        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'permission enumeration', 'SpaceManager',
            name: 'app',
            path: '/v2/apps',
            enumerate: 1
        end

        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'permission enumeration', 'Developer',
            name: 'app',
            path: '/v2/apps',
            enumerate: 1
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'permission enumeration', 'SpaceAuditor',
            name: 'app',
            path: '/v2/apps',
            enumerate: 1
        end
      end
    end

    describe 'Validation messages' do
      let(:space) { Space.make }
      let!(:app_obj) { App.make(space: space, state: 'STARTED', package_hash: 'some-made-up-package-hash') }

      it 'returns duplicate app name message correctly' do
        existing_app = App.make(space: space)
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(name: existing_app.name), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100002)
      end

      it 'returns organization quota memory exceeded message correctly' do
        space.organization.quota_definition = QuotaDefinition.make(memory_limit: 0)
        space.organization.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100005)
      end

      it 'returns space quota memory exceeded message correctly' do
        space.space_quota_definition = SpaceQuotaDefinition.make(memory_limit: 0)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310003)
      end

      it 'validates space quota memory limit before organization quotas' do
        space.organization.quota_definition = QuotaDefinition.make(memory_limit: 0)
        space.organization.save(validate: false)
        space.space_quota_definition = SpaceQuotaDefinition.make(memory_limit: 0)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310003)
      end

      it 'returns memory invalid message correctly' do
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 0), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100006)
      end

      it 'returns instance memory limit exceeded error correctly' do
        space.organization.quota_definition = QuotaDefinition.make(instance_memory_limit: 100)
        space.organization.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100007)
      end

      it 'returns space instance memory limit exceeded error correctly' do
        space.space_quota_definition = SpaceQuotaDefinition.make(instance_memory_limit: 100)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310004)
      end

      it 'returns app instance limit exceeded error correctly' do
        space.organization.quota_definition = QuotaDefinition.make(app_instance_limit: 4)
        space.organization.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(instances: 5), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100008)
      end

      it 'validates space quota instance memory limit before organization quotas' do
        space.organization.quota_definition = QuotaDefinition.make(instance_memory_limit: 100)
        space.organization.save(validate: false)
        space.space_quota_definition = SpaceQuotaDefinition.make(instance_memory_limit: 100)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(memory: 128), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310004)
      end

      it 'returns instances invalid message correctly' do
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(instances: -1), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to match /instances less than 0/
        expect(decoded_response['code']).to eq(100001)
      end

      it 'returns state invalid message correctly' do
        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(state: 'mississippi'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to match /Invalid app state provided/
        expect(decoded_response['code']).to eq(100001)
      end

      it 'validates space quota app instance limit' do
        space.space_quota_definition = SpaceQuotaDefinition.make(app_instance_limit: 2)
        space.save(validate: false)

        put "/v2/apps/#{app_obj.guid}", MultiJson.dump(instances: 3), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310008)
      end
    end
  end
end
