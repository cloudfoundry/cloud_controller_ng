require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::AppsController do
    let(:admin_user) { User.make }
    let(:non_admin_user) { User.make }
    let(:app_event_repository) { Repositories::AppEventRepository.new }
    before do
      set_current_user(non_admin_user)
      CloudController::DependencyLocator.instance.register(:app_event_repository, app_event_repository)
    end

    describe 'Query Parameters' do
      it { expect(VCAP::CloudController::AppsController).to be_queryable_by(:name) }
      it { expect(VCAP::CloudController::AppsController).to be_queryable_by(:space_guid) }
      it { expect(VCAP::CloudController::AppsController).to be_queryable_by(:organization_guid) }
      it { expect(VCAP::CloudController::AppsController).to be_queryable_by(:diego) }
      it { expect(VCAP::CloudController::AppsController).to be_queryable_by(:stack_guid) }
    end

    describe 'query by org_guid' do
      let(:process) { ProcessModelFactory.make }
      it 'filters apps by org_guid' do
        set_current_user_as_admin
        get "/v2/apps?q=organization_guid:#{process.organization.guid}"
        expect(last_response.status).to eq(200)
        expect(decoded_response['resources'][0]['entity']['name']).to eq(process.name)
      end
    end

    describe 'querying by stack guid' do
      let(:stack1) { Stack.make }
      let(:stack2) { Stack.make }
      let(:process1) { ProcessModel.make }
      let(:process2) { ProcessModel.make }

      before do
        process1.app.lifecycle_data.update(stack: stack1.name)
        process2.app.lifecycle_data.update(stack: stack2.name)
      end

      it 'filters apps by stack guid' do
        set_current_user_as_admin
        get "/v2/apps?q=stack_guid:#{stack1.guid}"
        expect(last_response.status).to eq(200)
        expect(decoded_response['resources'].length).to eq(1)
        expect(decoded_response['resources'][0]['entity']['name']).to eq(process1.name)
      end
    end

    describe 'Attributes' do
      it do
        expect(VCAP::CloudController::AppsController).to have_creatable_attributes(
          {
            enable_ssh:                 { type: 'bool' },
            buildpack:                  { type: 'string' },
            command:                    { type: 'string' },
            console:                    { type: 'bool', default: false },
            debug:                      { type: 'string' },
            disk_quota:                 { type: 'integer' },
            environment_json:           { type: 'hash', default: {} },
            health_check_http_endpoint: { type: 'string' },
            health_check_timeout:       { type: 'integer' },
            health_check_type:          { type: 'string', default: 'port' },
            instances:                  { type: 'integer', default: 1 },
            memory:                     { type: 'integer' },
            name:                       { type: 'string', required: true },
            production:                 { type: 'bool', default: false },
            state:                      { type: 'string', default: 'STOPPED' },
            space_guid:                 { type: 'string', required: true },
            stack_guid:                 { type: 'string' },
            diego:                      { type: 'bool' },
            docker_image:               { type: 'string', required: false },
            docker_credentials:         { type: 'hash', default: {} },
            ports:                      { type: '[integer]', default: nil }
          })
      end

      it do
        expect(VCAP::CloudController::AppsController).to have_updatable_attributes(
          {
            enable_ssh:                 { type: 'bool' },
            buildpack:                  { type: 'string' },
            command:                    { type: 'string' },
            console:                    { type: 'bool' },
            debug:                      { type: 'string' },
            disk_quota:                 { type: 'integer' },
            environment_json:           { type: 'hash' },
            health_check_http_endpoint: { type: 'string' },
            health_check_timeout:       { type: 'integer' },
            health_check_type:          { type: 'string' },
            instances:                  { type: 'integer' },
            memory:                     { type: 'integer' },
            name:                       { type: 'string' },
            production:                 { type: 'bool' },
            state:                      { type: 'string' },
            space_guid:                 { type: 'string' },
            stack_guid:                 { type: 'string' },
            diego:                      { type: 'bool' },
            docker_image:               { type: 'string' },
            docker_credentials:         { type: 'hash' },
            ports:                      { type: '[integer]' }
          })
      end
    end

    describe 'Associations' do
      it do
        expect(VCAP::CloudController::AppsController).to have_nested_routes(
          {
            events:           [:get, :put, :delete],
            service_bindings: [:get],
            routes:           [:get],
            route_mappings:   [:get],
          })
      end

      describe 'events associations (via AppEvents)' do
        before { set_current_user_as_admin }

        it 'does not return events with inline-relations-depth=0' do
          process = ProcessModel.make
          get "/v2/apps/#{process.app.guid}?inline-relations-depth=0"
          expect(entity).to have_key('events_url')
          expect(entity).to_not have_key('events')
        end

        it 'does not return events with inline-relations-depth=1 since app_events dataset is relatively expensive to query' do
          process = ProcessModel.make
          get "/v2/apps/#{process.app.guid}?inline-relations-depth=1"
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
          name:       'maria',
          space_guid: space_guid
        }
      end

      let(:decoded_response) { MultiJson.load(last_response.body) }
      let(:user_audit_info) { UserAuditInfo.from_context(SecurityContext) }

      describe 'events' do
        before do
          allow(UserAuditInfo).to receive(:from_context).and_return(user_audit_info)
        end
        it 'records app create' do
          set_current_user(admin_user, admin: true)

          expected_attrs = AppsController::CreateMessage.decode(initial_hash.to_json).extract(stringify_keys: true)
          allow(app_event_repository).to receive(:record_app_create).and_call_original

          post '/v2/apps', MultiJson.dump(initial_hash)

          process = ProcessModel.last
          expect(app_event_repository).to have_received(:record_app_create).with(process, process.space, user_audit_info, expected_attrs)
        end
      end

      context 'when the org is suspended' do
        before do
          space.organization.update(status: 'suspended')
        end

        it 'does not allow user to create new app (spot check)' do
          post '/v2/apps', MultiJson.dump(initial_hash)
          expect(last_response.status).to eq(403)
        end
      end

      context 'when allow_ssh is enabled globally' do
        before do
          TestConfig.override(allow_app_ssh_access: true)
        end

        context 'when allow_ssh is enabled on the space' do
          before do
            space.allow_ssh = true
            space.save
          end

          it 'allows enable_ssh to be set to true' do
            set_current_user_as_admin
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true))
            expect(last_response.status).to eq(201)
          end

          it 'allows enable_ssh to be set to false' do
            set_current_user_as_admin
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false))
            expect(last_response.status).to eq(201)
          end
        end

        context 'when allow_ssh is disabled on the space' do
          before do
            space.allow_ssh = false
            space.save
          end

          it 'allows enable_ssh to be set to false' do
            set_current_user_as_admin
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false))
            expect(last_response.status).to eq(201)
          end

          context 'and the user is an admin' do
            it 'allows enable_ssh to be set to true' do
              set_current_user_as_admin
              post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true))
              expect(last_response.status).to eq(201)
            end
          end

          context 'and the user is not an admin' do
            it 'errors when attempting to set enable_ssh to true' do
              set_current_user(non_admin_user)
              post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true))
              expect(last_response.status).to eq(400)
            end
          end
        end
      end

      context 'when allow_ssh is disabled globally' do
        before do
          set_current_user_as_admin
          TestConfig.override(allow_app_ssh_access: false)
        end

        context 'when allow_ssh is enabled on the space' do
          before do
            space.allow_ssh = true
            space.save
          end

          it 'errors when attempting to set enable_ssh to true' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true))
            expect(last_response.status).to eq(400)
          end

          it 'allows enable_ssh to be set to false' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false))
            expect(last_response.status).to eq(201)
          end
        end

        context 'when allow_ssh is disabled on the space' do
          before do
            space.allow_ssh = false
            space.save
          end

          it 'errors when attempting to set enable_ssh to true' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: true))
            expect(last_response.status).to eq(400)
          end

          it 'allows enable_ssh to be set to false' do
            post '/v2/apps', MultiJson.dump(initial_hash.merge(enable_ssh: false))
            expect(last_response.status).to eq(201)
          end
        end

        context 'when diego is set to true' do
          context 'when no custom ports are specified' do
            it 'sets the ports to 8080' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: true))
              expect(last_response.status).to eq(201)
              expect(decoded_response['entity']['ports']).to match([8080])
              expect(decoded_response['entity']['diego']).to be true
            end
          end

          context 'when custom ports are specified' do
            it 'sets the ports to as specified in the request' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: true, ports: [9090, 5222]))
              expect(last_response.status).to eq(201)
              expect(decoded_response['entity']['ports']).to match([9090, 5222])
              expect(decoded_response['entity']['diego']).to be true
            end
          end

          context 'when the custom port is not in the valid range 1024-65535' do
            it 'return an error' do
              post '/v2/apps', MultiJson.dump(initial_hash.merge(diego: true, ports: [9090, 500]))
              expect(last_response.status).to eq(400)
              expect(decoded_response['description']).to include('Ports must be in the 1024-65535.')
            end
          end
        end
      end

      it 'creates the app' do
        request = {
          name:                       'maria',
          space_guid:                 space.guid,
          environment_json:           { 'KEY' => 'val' },
          buildpack:                  'http://example.com/buildpack',
          health_check_http_endpoint: '/healthz',
          health_check_type:          'http',
        }

        set_current_user(admin_user, admin: true)

        post '/v2/apps', MultiJson.dump(request)

        v2_app = ProcessModel.last
        expect(v2_app.health_check_type).to eq('http')
        expect(v2_app.health_check_http_endpoint).to eq('/healthz')
      end

      it 'creates the app' do
        request = {
          name:             'maria',
          space_guid:       space.guid,
          environment_json: { 'KEY' => 'val' },
          buildpack:        'http://example.com/buildpack'
        }

        set_current_user(admin_user, admin: true)

        post '/v2/apps', MultiJson.dump(request)

        v2_app = ProcessModel.last
        expect(v2_app.name).to eq('maria')
        expect(v2_app.space).to eq(space)
        expect(v2_app.environment_json).to eq({ 'KEY' => 'val' })
        expect(v2_app.stack).to eq(Stack.default)
        expect(v2_app.buildpack.url).to eq('http://example.com/buildpack')

        v3_app = v2_app.app
        expect(v3_app.name).to eq('maria')
        expect(v3_app.space).to eq(space)
        expect(v3_app.environment_variables).to eq({ 'KEY' => 'val' })
        expect(v3_app.lifecycle_type).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
        expect(v3_app.lifecycle_data.stack).to eq(Stack.default.name)
        expect(v3_app.lifecycle_data.buildpacks).to eq(['http://example.com/buildpack'])
        expect(v3_app.desired_state).to eq(v2_app.state)

        expect(v3_app.guid).to eq(v2_app.guid)
      end

      context 'creating a buildpack app' do
        it 'creates the app correctly' do
          stack   = Stack.make(name: 'stack-name')
          request = {
            name:       'maria',
            space_guid: space.guid,
            stack_guid: stack.guid,
            buildpack:  'http://example.com/buildpack'
          }

          set_current_user(admin_user, admin: true)

          post '/v2/apps', MultiJson.dump(request)

          v2_app = ProcessModel.last
          expect(v2_app.stack).to eq(stack)
          expect(v2_app.buildpack.url).to eq('http://example.com/buildpack')
        end

        context 'when custom buildpacks are disabled and the buildpack attribute is being changed' do
          before do
            TestConfig.override({ disable_custom_buildpacks: true })
            set_current_user(admin_user, admin: true)
          end

          let(:request) do
            {
              name:       'maria',
              space_guid: space.guid,
            }
          end

          it 'does NOT allow a public git url' do
            post '/v2/apps', MultiJson.dump(request.merge(buildpack: 'http://example.com/buildpack'))

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Custom buildpacks are disabled')
          end

          it 'does NOT allow a public http url' do
            post '/v2/apps', MultiJson.dump(request.merge(buildpack: 'http://example.com/foo'))

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Custom buildpacks are disabled')
          end

          it 'does allow a buildpack name' do
            admin_buildpack = Buildpack.make
            post '/v2/apps', MultiJson.dump(request.merge(buildpack: admin_buildpack.name))

            expect(last_response.status).to eq(201)
          end

          it 'does not allow a private git url' do
            post '/v2/apps', MultiJson.dump(request.merge(buildpack: 'https://username:password@github.com/johndoe/my-buildpack.git'))

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Custom buildpacks are disabled')
          end

          it 'does not allow a private git url with ssh schema' do
            post '/v2/apps', MultiJson.dump(request.merge(buildpack: 'ssh://git@example.com:foo.git'))

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Custom buildpacks are disabled')
          end
        end
      end

      context 'creating a docker app' do
        it 'creates the app correctly' do
          request = {
            name:         'maria',
            space_guid:   space.guid,
            docker_image: 'some-image:latest',
          }

          set_current_user(admin_user, admin: true)

          post '/v2/apps', MultiJson.dump(request)

          v2_app = ProcessModel.last
          expect(v2_app.docker_image).to eq('some-image:latest')
          expect(v2_app.package_hash).to eq('some-image:latest')

          package = v2_app.latest_package
          expect(package.image).to eq('some-image:latest')
        end

        context 'when the package is invalid' do
          before do
            allow(VCAP::CloudController::PackageCreate).to receive(:create_without_event).
              and_raise(VCAP::CloudController::PackageCreate::InvalidPackage.new('oops'))
          end

          it 'returns an UnprocessableEntity error' do
            request = {
              name:         'maria',
              space_guid:   space.guid,
              docker_image: 'some-image:latest',
            }

            set_current_user(admin_user, admin: true)

            post '/v2/apps', MultiJson.dump(request)

            expect(last_response.status).to eq(422)
            expect(last_response.body).to match /UnprocessableEntity/
            expect(last_response.body).to match /oops/
          end
        end
      end

      context 'when starting an app without a package' do
        it 'raises an error' do
          request = {
            name:       'maria',
            space_guid: space.guid,
            state:      'STARTED'
          }

          set_current_user(admin_user, admin: true)

          post '/v2/apps', MultiJson.dump(request)
          expect(last_response.status).to eq(400)
          expect(last_response.body).to include('bits have not been uploaded')
        end
      end

      context 'when the space does not exist' do
        it 'returns 404' do
          set_current_user(admin_user, admin: true)

          post '/v2/apps', MultiJson.dump({ name: 'maria', space_guid: 'no-existy' })

          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'docker image credentials' do
      let(:space) { Space.make }
      let(:space_guid) { space.guid.to_s }
      let(:initial_hash) do
        {
          name:       'maria',
          space_guid: space_guid
        }
      end
      let(:decoded_response) { MultiJson.load(last_response.body) }

      let(:user) { 'user' }
      let(:password) { 'password' }
      let(:docker_credentials) do
        {
          username: user,
          password: password,
        }
      end
      let(:body) do
        MultiJson.dump(initial_hash.merge(docker_image: 'someimage', docker_credentials: docker_credentials))
      end
      let(:redacted_message) { '***' }

      def create_app
        post '/v2/apps', body
        expect(last_response).to have_status_code(201)
        decoded_response['metadata']['guid']
      end

      def read_app
        app_guid = create_app
        get "/v2/apps/#{app_guid}"
        expect(last_response).to have_status_code(200)
      end

      def update_app
        app_guid = create_app
        put "/v2/apps/#{app_guid}", body
        expect(last_response).to have_status_code(201)
      end

      before do
        set_current_user_as_admin
      end

      context 'create app' do
        it 'redacts the credentials' do
          create_app
          expect(decoded_response['entity']['docker_credentials']['password']).to eq redacted_message
        end
      end

      context 'read app' do
        it 'redacts the credentials' do
          read_app
          expect(decoded_response['entity']['docker_credentials']['password']).to eq redacted_message
        end
      end

      context 'update app' do
        it 'redacts the credentials' do
          update_app
          expect(decoded_response['entity']['docker_credentials']['password']).to eq redacted_message
        end
      end
    end

    describe 'update app' do
      let(:update_hash) { {} }

      let(:process) { ProcessModelFactory.make(diego: false, instances: 1) }
      let(:developer) { make_developer_for_space(process.space) }

      before do
        set_current_user(developer)
        allow_any_instance_of(V2::AppStage).to receive(:stage).and_return(nil)
      end

      describe 'app_scaling feature flag' do
        context 'when the flag is enabled' do
          before { FeatureFlag.make(name: 'app_scaling', enabled: true) }

          it 'allows updating memory' do
            put "/v2/apps/#{process.app.guid}", '{ "memory": 2 }'
            expect(last_response.status).to eq(201)
          end
        end

        context 'when the flag is disabled' do
          before { FeatureFlag.make(name: 'app_scaling', enabled: false, error_message: nil) }

          it 'fails with the proper error code and message' do
            put "/v2/apps/#{process.app.guid}", '{ "memory": 2 }'
            expect(last_response.status).to eq(403)
            expect(decoded_response['error_code']).to match(/FeatureDisabled/)
            expect(decoded_response['description']).to match(/app_scaling/)
          end
        end
      end

      context 'switch from dea to diego' do
        let(:process) { ProcessModelFactory.make(instances: 1, diego: false, type: 'web') }
        let(:developer) { make_developer_for_space(process.space) }
        let(:route) { Route.make(space: process.space) }
        let(:route_mapping) { RouteMappingModel.make(app: process.app, route: route) }

        it 'sets ports to 8080' do
          expect(process.ports).to be_nil
          put "/v2/apps/#{process.app.guid}", '{ "diego": true }'
          expect(last_response.status).to eq(201)
          expect(decoded_response['entity']['ports']).to match([8080])
          expect(decoded_response['entity']['diego']).to be true
        end
      end

      context 'switch from diego to dea' do
        let(:process) { ProcessModelFactory.make(instances: 1, diego: true, ports: [8080, 5222]) }
        it 'updates the backend of the app and returns 201 with warning' do
          put "/v2/apps/#{process.app.guid}", '{ "diego": false}'
          expect(last_response).to have_status_code(201)
          expect(decoded_response['entity']['diego']).to be false
          warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])
          expect(warning).to include('App ports have changed but are unknown. The app should now listen on the port specified by environment variable PORT')
        end
      end

      context 'when app is diego app' do
        let(:process) { ProcessModelFactory.make(instances: 1, diego: true, ports: [9090, 5222]) }

        it 'sets ports to user specified values' do
          put "/v2/apps/#{process.app.guid}", '{ "ports": [1883,5222] }'
          expect(last_response.status).to eq(201)
          expect(decoded_response['entity']['ports']).to match([1883, 5222])
          expect(decoded_response['entity']['diego']).to be true
        end

        context 'when not updating ports' do
          it 'should keep previously specified custom ports' do
            put "/v2/apps/#{process.app.guid}", '{ "instances":2 }'
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['ports']).to match([9090, 5222])
            expect(decoded_response['entity']['diego']).to be true
          end
        end

        context 'when the user sets ports to an empty array' do
          it 'should keep previously specified custom ports' do
            put "/v2/apps/#{process.app.guid}", '{ "ports":[] }'
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['ports']).to match([9090, 5222])
            expect(decoded_response['entity']['diego']).to be true
          end
        end

        context 'when updating an app with existing route mapping' do
          let(:route) { Route.make(space: process.space) }
          let!(:route_mapping) { RouteMappingModel.make(app: process.app, route: route, app_port: 9090) }
          let!(:route_mapping2) { RouteMappingModel.make(app: process.app, route: route, app_port: 5222) }

          context 'when new app ports contains all existing route port mappings' do
            it 'updates the ports' do
              put "/v2/apps/#{process.app.guid}", '{ "ports":[9090, 5222, 1234] }'
              expect(last_response.status).to eq(201)
              expect(decoded_response['entity']['ports']).to match([9090, 5222, 1234])
            end
          end

          context 'when new app ports partially contains existing route port mappings' do
            it 'returns 400' do
              put "/v2/apps/#{process.app.guid}", '{ "ports":[5222, 1234] }'
              expect(last_response.status).to eq(400)
              expect(decoded_response['description']).to include('App ports ports may not be removed while routes are mapped to them.')
            end
          end

          context 'when new app ports do not contain existing route mapping port' do
            it 'returns 400' do
              put "/v2/apps/#{process.app.guid}", '{ "ports":[1234] }'
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

            expect(app_event_repository).to receive(:record_app_update) do |recorded_app, recorded_space, user_audit_info, attributes|
              expect(recorded_app.guid).to eq(process.app.guid)
              expect(recorded_app.instances).to eq(2)
              expect(user_audit_info.user_guid).to eq(SecurityContext.current_user)
              expect(user_audit_info.user_name).to eq(SecurityContext.current_user_email)
              expect(attributes).to eq({ 'instances' => 2 })
            end

            put "/v2/apps/#{process.app.guid}", MultiJson.dump(update_hash)
          end
        end

        context 'when the update fails' do
          before do
            allow_any_instance_of(ProcessModel).to receive(:save).and_raise('Error saving')
            allow(app_event_repository).to receive(:record_app_update)
          end

          it 'does not record app update' do
            put "/v2/apps/#{process.app.guid}", MultiJson.dump(update_hash)

            expect(app_event_repository).to_not have_received(:record_app_update)
            expect(last_response.status).to eq(500)
          end
        end
      end

      it 'updates the app' do
        v2_app = ProcessModel.make
        v3_app = v2_app.app
        stack  = Stack.make(name: 'stack-name')

        request = {
          name:             'maria',
          environment_json: { 'KEY' => 'val' },
          stack_guid:       stack.guid,
          buildpack:        'http://example.com/buildpack',
        }

        set_current_user(admin_user, admin: true)

        put "/v2/apps/#{v2_app.app.guid}", MultiJson.dump(request)
        expect(last_response.status).to eq(201)

        v2_app.reload
        v3_app.reload

        expect(v2_app.name).to eq('maria')
        expect(v2_app.environment_json).to eq({ 'KEY' => 'val' })
        expect(v2_app.stack).to eq(stack)
        expect(v2_app.buildpack.url).to eq('http://example.com/buildpack')

        expect(v3_app.name).to eq('maria')
        expect(v3_app.environment_variables).to eq({ 'KEY' => 'val' })
        expect(v3_app.lifecycle_type).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
        expect(v3_app.lifecycle_data.stack).to eq('stack-name')
        expect(v3_app.lifecycle_data.buildpacks).to eq(['http://example.com/buildpack'])
      end

      context 'when custom buildpacks are disabled and the buildpack attribute is being changed' do
        before do
          TestConfig.override({ disable_custom_buildpacks: true })
          set_current_user(admin_user, admin: true)
          process.app.lifecycle_data.update(buildpacks: [Buildpack.make.name])
        end

        let(:process) { ProcessModel.make }

        it 'does NOT allow a public git url' do
          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ buildpack: 'http://example.com/buildpack' })

          expect(last_response.status).to eq(400)
          expect(last_response.body).to include('Custom buildpacks are disabled')
        end

        it 'does NOT allow a public http url' do
          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ buildpack: 'http://example.com/foo' })

          expect(last_response.status).to eq(400)
          expect(last_response.body).to include('Custom buildpacks are disabled')
        end

        it 'does allow a buildpack name' do
          admin_buildpack = Buildpack.make
          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ buildpack: admin_buildpack.name })

          expect(last_response.status).to eq(201)
        end

        it 'does not allow a private git url' do
          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ buildpack: 'git@example.com:foo.git' })

          expect(last_response.status).to eq(400)
          expect(last_response.body).to include('Custom buildpacks are disabled')
        end

        it 'does not allow a private git url with ssh schema' do
          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ buildpack: 'ssh://git@example.com:foo.git' })

          expect(last_response.status).to eq(400)
          expect(last_response.body).to include('Custom buildpacks are disabled')
        end
      end

      describe 'setting stack' do
        let(:new_stack) { Stack.make }

        it 'changes the stack' do
          set_current_user(admin_user, admin: true)

          process = ProcessModelFactory.make

          expect(process.stack).not_to eq(new_stack)

          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ stack_guid: new_stack.guid })

          expect(last_response.status).to eq(201)
          expect(process.reload.stack).to eq(new_stack)
        end

        context 'when the app is already staged' do
          let(:process) do
            ProcessModelFactory.make(
              instances: 1,
              state:     'STARTED')
          end

          it 'marks the app for re-staging' do
            expect(process.needs_staging?).to eq(false)

            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ stack_guid: new_stack.guid })
            expect(last_response.status).to eq(201)
            process.reload

            expect(process.needs_staging?).to eq(true)
            expect(process.staged?).to eq(false)
          end
        end

        context 'when the app needs staged' do
          let(:process) { ProcessModelFactory.make(state: 'STARTED') }

          before do
            PackageModel.make(app: process.app, package_hash: 'some-hash', state: PackageModel::READY_STATE)
            process.reload
          end

          it 'keeps app as needs staging' do
            expect(process.staged?).to be false
            expect(process.needs_staging?).to be true

            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ stack_guid: new_stack.guid })
            expect(last_response.status).to eq(201)
            process.reload

            expect(process.staged?).to be false
            expect(process.needs_staging?).to be true
          end
        end

        context 'when the app was never staged' do
          let(:process) { ProcessModel.make }

          it 'does not mark the app for staging' do
            expect(process.staged?).to be_falsey
            expect(process.needs_staging?).to be_nil

            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ stack_guid: new_stack.guid })
            expect(last_response.status).to eq(201)
            process.reload

            expect(process.staged?).to be_falsey
            expect(process.needs_staging?).to be_nil
          end
        end
      end

      describe 'changing lifecycle types' do
        context 'when changing from docker to buildpack' do
          let(:process) { ProcessModel.make(app: AppModel.make(:docker)) }

          it 'raises an error setting buildpack' do
            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ buildpack: 'https://buildpack.example.com' })
            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Lifecycle type cannot be changed')
          end

          it 'raises an error setting stack' do
            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ stack_guid: 'phat-stackz' })
            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Lifecycle type cannot be changed')
          end
        end

        context 'when changing from buildpack to docker' do
          let(:process) { ProcessModel.make(app: AppModel.make(:buildpack)) }

          it 'raises an error' do
            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ docker_image: 'repo/great-image' })
            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Lifecycle type cannot be changed')
          end
        end
      end

      describe 'updating docker_image' do
        before do
          set_current_user(admin_user, admin: true)
        end

        it 'creates a new docker package' do
          process          = ProcessModelFactory.make(app: AppModel.make(:docker), docker_image: 'repo/original-image')
          original_package = process.latest_package

          expect(process.docker_image).not_to eq('repo/new-image')

          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ docker_image: 'repo/new-image' })
          expect(last_response.status).to eq(201)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['entity']['docker_image']).to eq('repo/new-image')
          expect(parsed_response['entity']['docker_credentials']).to eq({
            'username' => nil,
            'password' => nil
          })
          expect(process.reload.docker_image).to eq('repo/new-image')
          expect(process.latest_package).not_to eq(original_package)
        end

        context 'when credentials are requested' do
          let(:docker_credentials) do
            { 'username' => 'fred', 'password' => 'derf' }
          end

          it 'creates a new docker package with those credentials' do
            process          = ProcessModelFactory.make(app: AppModel.make(:docker), docker_image: 'repo/original-image')
            original_package = process.latest_package

            expect(process.docker_image).not_to eq('repo/new-image')

            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ docker_image: 'repo/new-image', docker_credentials: docker_credentials })
            expect(last_response.status).to eq(201)

            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['entity']['docker_image']).to eq('repo/new-image')
            expect(parsed_response['entity']['docker_credentials']).to eq({
              'username' => 'fred',
              'password' => '***'
            })
            expect(process.reload.docker_image).to eq('repo/new-image')
            expect(process.latest_package).not_to eq(original_package)
          end
        end

        context 'when the package is invalid' do
          before do
            allow(VCAP::CloudController::PackageCreate).to receive(:create_without_event).
              and_raise(VCAP::CloudController::PackageCreate::InvalidPackage.new('oops'))
          end

          it 'returns an UnprocessableEntity error' do
            set_current_user(admin_user, admin: true)
            process = ProcessModelFactory.make(app: AppModel.make(:docker), docker_image: 'repo/original-image')

            put "/v2/apps/#{process.app.guid}", MultiJson.dump({ docker_credentials: { username: 'username', password: 'foo' } })

            expect(last_response.status).to eq(422)
            expect(last_response.body).to match /UnprocessableEntity/
            expect(last_response.body).to match /oops/
          end
        end
      end

      describe 'staging' do
        let(:app_stage) { instance_double(V2::AppStage, stage: nil) }
        let(:process) { ProcessModelFactory.make }

        before do
          allow(V2::AppStage).to receive(:new).and_return(app_stage)
          process.update(state: 'STARTED')
        end

        context 'when a state change is requested' do
          let(:req) { '{ "state": "STARTED" }' }

          context 'when the app needs staging' do
            before do
              process.app.update(droplet: nil)
              process.reload
            end

            it 'requests to be staged' do
              put "/v2/apps/#{process.app.guid}", req
              expect(last_response.status).to eq(201)

              expect(app_stage).to have_received(:stage)
            end
          end

          context 'when the app does not need staging' do
            it 'does not request to be staged' do
              put "/v2/apps/#{process.app.guid}", req
              expect(last_response.status).to eq(201)

              expect(app_stage).not_to have_received(:stage)
            end
          end
        end

        context 'when a state change is NOT requested' do
          let(:req) { '{ "name": "some-name" }' }

          context 'when the app needs staging' do
            before do
              process.app.update(droplet: nil)
              process.reload
            end

            it 'does not request to be staged' do
              put "/v2/apps/#{process.app.guid}", req
              expect(last_response.status).to eq(201)

              expect(app_stage).not_to have_received(:stage)
            end
          end

          context 'when the app does not need staging' do
            it 'does not request to be staged' do
              put "/v2/apps/#{process.app.guid}", req
              expect(last_response.status).to eq(201)

              expect(app_stage).not_to have_received(:stage)
            end
          end
        end
      end

      context 'when starting an app without a package' do
        let(:process) { ProcessModel.make(instances: 1) }

        it 'raises an error' do
          put "/v2/apps/#{process.app.guid}", MultiJson.dump({ state: 'STARTED' })
          expect(last_response.status).to eq(400)
          expect(last_response.body).to include('bits have not been uploaded')
        end
      end

      describe 'starting and stopping' do
        let(:parent_app) { process.app }
        let(:process) { ProcessModelFactory.make(instances: 1, state: state) }
        let(:sibling) { ProcessModel.make(instances: 1, state: state, app: parent_app, type: 'worker') }

        context 'starting' do
          let(:state) { 'STOPPED' }

          it 'is reflected in the parent app and all sibling processes' do
            expect(parent_app.desired_state).to eq('STOPPED')
            expect(process.state).to eq('STOPPED')
            expect(sibling.state).to eq('STOPPED')

            put "/v2/apps/#{process.app.guid}", '{ "state": "STARTED" }'
            expect(last_response.status).to eq(201)

            expect(parent_app.reload.desired_state).to eq('STARTED')
            expect(process.reload.state).to eq('STARTED')
            expect(sibling.reload.state).to eq('STARTED')
          end
        end

        context 'stopping' do
          let(:state) { 'STARTED' }

          it 'is reflected in the parent app and all sibling processes' do
            expect(parent_app.desired_state).to eq('STARTED')
            expect(process.state).to eq('STARTED')
            expect(sibling.state).to eq('STARTED')

            put "/v2/apps/#{process.app.guid}", '{ "state": "STOPPED" }'
            expect(last_response.status).to eq(201)

            expect(parent_app.reload.desired_state).to eq('STOPPED')
            expect(process.reload.state).to eq('STOPPED')
            expect(sibling.reload.state).to eq('STOPPED')
          end
        end

        context 'invalid state' do
          let(:state) { 'STOPPED' }

          it 'raises an error' do
            put "/v2/apps/#{process.app.guid}", '{ "state": "ohio" }'
            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Invalid app state')
          end
        end
      end
    end

    describe 'delete an app' do
      let(:process) { ProcessModelFactory.make }
      let(:developer) { make_developer_for_space(process.space) }
      let(:decoded_response) { MultiJson.load(last_response.body) }
      let(:parent_app) { process.app }

      before do
        set_current_user(developer)
      end

      def delete_app
        delete "/v2/apps/#{process.app.guid}"
      end

      it 'deletes the app' do
        expect(process.exists?).to be_truthy
        expect(parent_app.exists?).to be_truthy

        delete_app

        expect(last_response.status).to eq(204)
        expect(process.exists?).to be_falsey
        expect(parent_app.exists?).to be_falsey
      end

      context 'when the app disappears after the find_validate_access_check' do
        before do
          allow_any_instance_of(AppDelete).to receive(:delete_without_event).and_raise(Sequel::NoExistingObject)
        end

        it 'throws a not_found_exception' do
          delete_app
          expect(last_response.status).to eq(404)
          expect(parsed_response['description']).to eq("The app could not be found: #{parent_app.guid}")
        end
      end

      context 'non recursive deletion' do
        context 'with NON-empty service_binding association' do
          let!(:svc_instance) { ManagedServiceInstance.make(space: process.space) }
          let!(:service_binding) { ServiceBinding.make(app: process.app, service_instance: svc_instance) }
          let(:guid_pattern) { '[[:alnum:]-]+' }

          before do
            service_broker = svc_instance.service.service_broker
            uri            = URI(service_broker.broker_url)
            broker_url     = uri.host + uri.path
            stub_request(
              :delete,
              %r{https://#{broker_url}/v2/service_instances/#{guid_pattern}/service_bindings/#{guid_pattern}}).
              with(basic_auth: basic_auth(service_broker: service_broker)).
              to_return(status: 200, body: '{}')
          end

          it 'should raise an error' do
            delete_app

            expect(last_response.status).to eq(400)
            expect(decoded_response['description']).to match(/service_bindings/i)
          end

          it 'should succeed on a recursive delete' do
            delete "/v2/apps/#{process.app.guid}?recursive=true"

            expect(last_response).to have_status_code(204)
          end
        end
      end

      describe 'events' do
        it 'records an app delete-request' do
          delete_app

          event = Event.find(type: 'audit.app.delete-request', actee_type: 'app')
          expect(event.type).to eq('audit.app.delete-request')
          expect(event.metadata).to eq({ 'request' => { 'recursive' => false } })
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(process.app.guid)
          expect(event.actee_type).to eq('app')
        end

        it 'records the recursive query parameter when recursive' do
          delete "/v2/apps/#{process.app.guid}?recursive=true"

          event = Event.find(type: 'audit.app.delete-request', actee_type: 'app')
          expect(event.type).to eq('audit.app.delete-request')
          expect(event.metadata).to eq({ 'request' => { 'recursive' => true } })
          expect(event.actor).to eq(developer.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(process.app.guid)
          expect(event.actee_type).to eq('app')
        end

        it 'does not record when the destroy fails' do
          allow_any_instance_of(ProcessModel).to receive(:destroy).and_raise('Error saving')

          delete_app

          expect(Event.where(type: 'audit.app.delete-request').count).to eq(0)
        end
      end
    end

    describe 'route mapping' do
      let!(:process) { ProcessModelFactory.make(instances: 1, diego: true) }
      let!(:developer) { make_developer_for_space(process.space) }
      let!(:route) { Route.make(space: process.space) }
      let!(:route_mapping) { RouteMappingModel.make(app: process.app, route: route, process_type: process.type) }

      before do
        set_current_user(developer)
      end

      context 'GET' do
        it 'returns the route mapping' do
          get "/v2/apps/#{process.app.guid}/route_mappings"
          expect(last_response.status).to eql(200)
          parsed_body = parse(last_response.body)
          expect(parsed_body['resources'].first['entity']['route_guid']).to eq(route.guid)
          expect(parsed_body['resources'].first['entity']['app_guid']).to eq(process.app.guid)
        end
      end

      context 'POST' do
        it 'returns 404' do
          post "/v2/apps/#{process.app.guid}/route_mappings", '{}'
          expect(last_response.status).to eql(404)
        end
      end

      context 'PUT' do
        it 'returns 404' do
          put "/v2/apps/#{process.app.guid}/route_mappings/#{route_mapping.guid}", '{}'
          expect(last_response.status).to eql(404)
        end
      end

      context 'DELETE' do
        it 'returns 404' do
          delete "/v2/apps/#{process.app.guid}/route_mappings/#{route_mapping.guid}"
          expect(last_response.status).to eql(404)
        end
      end
    end

    describe "read an app's env" do
      let(:space) { process.space }
      let(:developer) { make_developer_for_space(space) }
      let(:auditor) { make_auditor_for_space(space) }
      let(:process) { ProcessModelFactory.make(detected_buildpack: 'buildpack-name') }
      let(:decoded_response) { MultiJson.load(last_response.body) }

      before do
        set_current_user(developer)
      end

      context 'when the user is a member of the space this app exists in' do
        context 'when the user is not a space developer' do
          before do
            set_current_user(User.make)
          end

          it 'returns a JSON payload indicating they do not have permission to read this endpoint' do
            get "/v2/apps/#{process.app.guid}/env"
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('You are not authorized to perform the requested action')
          end
        end

        context 'when the user has only the cloud_controller.read scope' do
          before do
            set_current_user(developer, { scopes: ['cloud_controller.read'] })
          end

          it 'returns successfully' do
            get "/v2/apps/#{process.app.guid}/env"
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
          it 'returns application environment with VCAP_APPLICATION' do
            get "/v2/apps/#{process.app.guid}/env"
            expect(last_response.status).to eql(200)

            expect(decoded_response['application_env_json']).to have_key('VCAP_APPLICATION')
            expect(decoded_response['application_env_json']).to match({
              'VCAP_APPLICATION' => {
                'cf_api'              => "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
                'limits'              => {
                  'mem'  => process.memory,
                  'disk' => process.disk_quota,
                  'fds'  => 16384
                },
                'application_id'      => process.app.guid,
                'application_name'    => process.name,
                'name'                => process.name,
                'application_uris'    => [],
                'uris'                => [],
                'application_version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                'version'             => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                'space_name'          => process.space.name,
                'space_id'            => process.space.guid,
                'users'               => nil
              }
            })
          end
        end

        context 'when the user is space dev and has service instance bound to application' do
          let!(:service_instance) { ManagedServiceInstance.make(space: process.space) }
          let!(:service_binding) { ServiceBinding.make(app: process.app, service_instance: service_instance) }

          it 'returns system environment with VCAP_SERVICES' do
            get "/v2/apps/#{process.app.guid}/env"
            expect(last_response.status).to eql(200)

            expect(decoded_response['system_env_json']['VCAP_SERVICES']).not_to eq({})
          end

          context 'when the service binding is being asynchronously created' do
            let(:operation) { ServiceBindingOperation.make(state: 'in progress') }

            before do
              service_binding.service_binding_operation = operation
            end

            it 'does not include the binding in VCAP_SERVICES' do
              get "/v2/apps/#{process.app.guid}/env"
              expect(last_response.status).to eql(200)

              expect(decoded_response['system_env_json']['VCAP_SERVICES']).to eq({})
            end
          end
        end

        context 'when the staging env variable group is set' do
          before do
            staging_group                  = EnvironmentVariableGroup.staging
            staging_group.environment_json = { POTATO: 'delicious' }
            staging_group.save
          end

          it 'returns staging_env_json with those variables' do
            get "/v2/apps/#{process.app.guid}/env"
            expect(last_response.status).to eql(200)

            expect(decoded_response['staging_env_json'].size).to eq(1)
            expect(decoded_response['staging_env_json']).to have_key('POTATO')
            expect(decoded_response['staging_env_json']['POTATO']).to eq('delicious')
          end
        end

        context 'when the running env variable group is set' do
          before do
            running_group                  = EnvironmentVariableGroup.running
            running_group.environment_json = { PIE: 'sweet' }
            running_group.save
          end

          it 'returns staging_env_json with those variables' do
            get "/v2/apps/#{process.app.guid}/env"
            expect(last_response.status).to eql(200)

            expect(decoded_response['running_env_json'].size).to eq(1)
            expect(decoded_response['running_env_json']).to have_key('PIE')
            expect(decoded_response['running_env_json']['PIE']).to eq('sweet')
          end
        end

        context 'when the user does not have the necessary scope' do
          before do
            set_current_user(developer, { scopes: ['cloud_controller.write'] })
          end

          it 'returns InsufficientScope' do
            get "/v2/apps/#{process.app.guid}/env"
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('Your token lacks the necessary scopes to access this resource.')
          end
        end
      end

      context 'when the user is a global auditor' do
        before do
          set_current_user_as_global_auditor
        end

        it 'should not be able to read environment variables' do
          get "/v2/apps/#{process.app.guid}/env"
          expect(last_response.status).to eql(403)
          expect(JSON.parse(last_response.body)['description']).to eql('You are not authorized to perform the requested action')
        end
      end

      context 'when the user reads environment variables from the app endpoint using inline-relations-depth=2' do
        let!(:test_environment_json) { { 'environ_key' => 'value' } }
        let(:parent_app) { AppModel.make(environment_variables: test_environment_json) }
        let!(:process) do
          ProcessModelFactory.make(
            detected_buildpack: 'buildpack-name',
            app:                parent_app
          )
        end
        let!(:service_instance) { ManagedServiceInstance.make(space: process.space) }
        let!(:service_binding) { ServiceBinding.make(app: process.app, service_instance: service_instance) }

        context 'when the user is a space developer' do
          it 'returns non-redacted environment values' do
            get '/v2/apps?inline-relations-depth=2'
            expect(last_response.status).to eql(200)

            expect(decoded_response['resources'].first['entity']['environment_json']).to eq(test_environment_json)
            expect(decoded_response).not_to have_key('system_env_json')
          end
        end

        context 'when the user is not a space developer' do
          before do
            set_current_user(auditor)
          end

          it 'returns redacted values' do
            get '/v2/apps?inline-relations-depth=2'
            expect(last_response.status).to eql(200)

            expect(decoded_response['resources'].first['entity']['environment_json']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
            expect(decoded_response).not_to have_key('system_env_json')
          end
        end
      end

      context 'when the user is NOT a member of the space this instance exists in' do
        let(:process) { ProcessModelFactory.make(detected_buildpack: 'buildpack-name') }

        before do
          set_current_user(User.make)
        end

        it 'returns access denied' do
          get "/v2/apps/#{process.app.guid}/env"
          expect(last_response.status).to eql(403)
        end
      end

      context 'when the user has not authenticated with Cloud Controller' do
        let(:developer) { nil }

        it 'returns an error saying that the user is not authenticated' do
          get "/v2/apps/#{process.app.guid}/env"
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the app does not exist' do
        it 'returns not found' do
          get '/v2/apps/nonexistentappguid/env'
          expect(last_response.status).to eql 404
        end
      end

      context 'when the space_developer_env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 for non-admins' do
          get "/v2/apps/#{process.app.guid}/env"

          expect(last_response.status).to eq(403)
          expect(last_response.body).to include('FeatureDisabled')
          expect(last_response.body).to include('space_developer_env_var_visibility')
        end

        it 'succeeds for admins' do
          set_current_user_as_admin
          get "/v2/apps/#{process.app.guid}/env"

          expect(last_response.status).to eq(200)
        end

        it 'succeeds for admin_read_onlys' do
          set_current_user_as_admin_read_only
          get "/v2/apps/#{process.app.guid}/env"

          expect(last_response.status).to eq(200)
        end

        context 'when the user is not a space developer' do
          before do
            set_current_user(auditor)
          end

          it 'indicates they do not have permission rather than that the feature flag is disabled' do
            get "/v2/apps/#{process.app.guid}/env"
            expect(last_response.status).to eql(403)
            expect(JSON.parse(last_response.body)['description']).to eql('You are not authorized to perform the requested action')
          end
        end
      end

      context 'when the env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'env_var_visibility', enabled: false, error_message: nil)
        end

        it 'raises 403 all user' do
          set_current_user_as_admin
          get "/v2/apps/#{process.app.guid}/env"

          expect(last_response.status).to eq(403)
          expect(last_response.body).to include('Feature Disabled: env_var_visibility')
        end

        context 'when the space_developer_env_var_visibility feature flag is enabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: true, error_message: nil)
          end

          it 'raises 403 for non-admins' do
            set_current_user(developer)
            get "/v2/apps/#{process.app.guid}/env"

            expect(last_response.status).to eq(403)
            expect(last_response.body).to include('Feature Disabled: env_var_visibility')
          end
        end
      end

      context 'when the env_var_visibility feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'env_var_visibility', enabled: true, error_message: nil)
        end

        it 'continues to show 403 for roles that never had access to envs' do
          set_current_user(auditor)
          get "/v2/apps/#{process.app.guid}/env"

          expect(last_response.status).to eq(403)
          expect(last_response.body).to include('NotAuthorized')
        end

        it 'show envs for admins' do
          set_current_user_as_admin
          get "/v2/apps/#{process.app.guid}/env"

          expect(last_response.status).to eq(200)
          expect(decoded_response['application_env_json']).to match({
            'VCAP_APPLICATION' => {
              'cf_api'              => "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
              'limits'              => {
                'mem'  => process.memory,
                'disk' => process.disk_quota,
                'fds'  => 16384
              },
              'application_id'      => process.app.guid,
              'application_name'    => process.name,
              'name'                => process.name,
              'application_uris'    => [],
              'uris'                => [],
              'application_version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
              'version'             => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
              'space_name'          => process.space.name,
              'space_id'            => process.space.guid,
              'users'               => nil
            }
          })
        end

        context 'when the space_developer_env_var_visibility feature flag is disabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
          end

          it 'raises 403 for space developers' do
            set_current_user(developer)
            get "/v2/apps/#{process.app.guid}/env"

            expect(last_response.status).to eq(403)
            expect(last_response.body).to include('Feature Disabled: space_developer_env_var_visibility')
          end
        end
      end
    end

    describe 'staging' do
      let(:developer) { make_developer_for_space(process.space) }

      before do
        set_current_user(developer)
        Buildpack.make
      end

      context 'when app will be staged', isolation: :truncation do
        let(:process) do
          ProcessModelFactory.make(diego: false, state: 'STOPPED', instances: 1).tap do |p|
            p.current_droplet.destroy
            p.reload
          end
        end
        let(:stager_response) do
          double('StagingResponse', streaming_log_url: 'streaming-log-url')
        end
        let(:app_stager_task) do
          double(Diego::Stager, stage: stager_response)
        end

        before do
          allow(Diego::Stager).to receive(:new).and_return(app_stager_task)
        end

        it 'returns X-App-Staging-Log header with staging log url' do
          put "/v2/apps/#{process.app.guid}", MultiJson.dump(state: 'STARTED')
          expect(last_response.status).to eq(201), last_response.body
          expect(last_response.headers['X-App-Staging-Log']).to eq('streaming-log-url')
        end
      end

      context 'when app will not be staged' do
        let(:process) { ProcessModelFactory.make(state: 'STOPPED') }

        it 'does not add X-App-Staging-Log' do
          put "/v2/apps/#{process.app.guid}", MultiJson.dump({})
          expect(last_response.status).to eq(201)
          expect(last_response.headers).not_to have_key('X-App-Staging-Log')
        end
      end
    end

    describe 'downloading the droplet' do
      let(:process) { ProcessModelFactory.make }
      let(:blob) { instance_double(CloudController::Blobstore::FogBlob) }
      let(:developer) { make_developer_for_space(process.space) }

      before do
        set_current_user(developer)
        allow(blob).to receive(:public_download_url).and_return('http://example.com/somewhere/else')
        allow_any_instance_of(CloudController::Blobstore::Client).to receive(:blob).and_return(blob)
      end

      it 'should let the user download the droplet' do
        get "/v2/apps/#{process.app.guid}/droplet/download", MultiJson.dump({})
        expect(last_response).to be_redirect
        expect(last_response.header['Location']).to eq('http://example.com/somewhere/else')
      end

      it 'should return an error for non-existent apps' do
        get '/v2/apps/bad/droplet/download', MultiJson.dump({})
        expect(last_response.status).to eq(404)
      end

      it 'should return an error for an app without a droplet' do
        process.current_droplet.destroy

        get "/v2/apps/#{process.app.guid}/droplet/download", MultiJson.dump({})
        expect(last_response.status).to eq(404)
      end
    end

    describe 'uploading the droplet' do
      before do
        TestConfig.override(directories: { tmpdir: File.dirname(valid_zip.path) })
      end

      let(:process) { ProcessModel.make }

      let(:tmpdir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(tmpdir) }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, 'file.zip')
        TestZip.create(zip_name, 1, 1024)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      context 'as an admin' do
        let(:req_body) { { droplet: valid_zip } }

        it 'is allowed' do
          set_current_user(User.make, admin: true)
          put "/v2/apps/#{process.app.guid}/droplet/upload", req_body

          expect(last_response.status).to eq(201)
        end
      end

      context 'as a developer' do
        let(:user) { make_developer_for_space(process.space) }

        context 'with an empty request' do
          it 'fails to upload' do
            set_current_user(user)
            put "/v2/apps/#{process.app.guid}/droplet/upload", {}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['description']).to include('missing :droplet_path')
          end
        end

        context 'with valid request' do
          let(:req_body) { { droplet: valid_zip } }

          it 'creates a delayed job' do
            set_current_user(user)
            expect {
              put "/v2/apps/#{process.app.guid}/droplet/upload", req_body
              expect(last_response.status).to eq 201
            }.to change {
              Delayed::Job.count
            }.by(1)

            job = Delayed::Job.last
            expect(job.handler).to include('V2::UploadDropletFromUser')
          end
        end
      end

      context 'as a non-developer' do
        let(:req_body) { { droplet: valid_zip } }

        it 'returns 403' do
          put "/v2/apps/#{process.app.guid}/droplet/upload", req_body
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'on route change', isolation: :truncation do
      let(:space) { process.space }
      let(:domain) do
        PrivateDomain.make(name: 'jesse.cloud', owning_organization: space.organization)
      end
      let(:process) { ProcessModelFactory.make(diego: false, state: 'STARTED') }

      before do
        FeatureFlag.create(name: 'diego_docker', enabled: true)
        set_current_user(make_developer_for_space(space))
      end

      it 'creates a route mapping when we add one url through PUT /v2/apps/:guid' do
        route = domain.add_route(
          host:  'app',
          space: space,
        )

        fake_route_mapping_create = instance_double(V2::RouteMappingCreate)
        allow(V2::RouteMappingCreate).to receive(:new).with(anything, route, process, anything, instance_of(Steno::Logger)).and_return(fake_route_mapping_create)
        expect(fake_route_mapping_create).to receive(:add)

        put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil
        expect(last_response.status).to eq(201)
      end

      context 'with Docker app' do
        let(:space) { docker_process.space }
        let(:route) { domain.add_route(host: 'app', space: space) }
        let(:pre_mapped_route) { domain.add_route(host: 'pre_mapped_route', space: space) }
        let(:docker_process) do
          ProcessModelFactory.make(
            state:        'STARTED',
            diego:        true,
            docker_image: 'some-image',
          )
        end

        before do
          put "/v2/apps/#{docker_process.app.guid}/routes/#{pre_mapped_route.guid}", nil
        end

        context 'when Docker is disabled' do
          before do
            allow_any_instance_of(Diego::Messenger).to receive(:send_desire_request)
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          end

          context 'and a route is mapped' do
            it 'succeeds' do
              put "/v2/apps/#{docker_process.app.guid}/routes/#{route.guid}", nil
              expect(last_response.status).to eq(201)
            end
          end

          context 'and a previously mapped route is unmapped' do
            it 'succeeds' do
              delete "/v2/apps/#{docker_process.app.guid}/routes/#{pre_mapped_route.guid}", nil
              expect(last_response.status).to eq(204)
            end
          end
        end
      end
    end

    describe 'on instance number change' do
      before do
        FeatureFlag.create(name: 'diego_docker', enabled: true)
      end

      context 'when docker is disabled' do
        let!(:started_process) do
          ProcessModelFactory.make(state: 'STARTED', docker_image: 'docker-image')
        end

        before do
          FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          set_current_user(make_developer_for_space(started_process.space))
        end

        it 'does not return docker disabled message' do
          put "/v2/apps/#{started_process.app.guid}", MultiJson.dump(instances: 2)

          expect(last_response.status).to eq(201)
        end
      end
    end

    describe 'on state change' do
      before do
        FeatureFlag.create(name: 'diego_docker', enabled: true)
      end

      context 'when docker is disabled' do
        let!(:stopped_process) {
          ProcessModelFactory.make(:docker, state: 'STOPPED', docker_image: 'docker-image', type: 'web')
        }
        let!(:started_process) {
          ProcessModelFactory.make(:docker, state: 'STARTED', docker_image: 'docker-image', type: 'web')
        }

        before do
          FeatureFlag.find(name: 'diego_docker').update(enabled: false)
        end

        it 'returns docker disabled message on start' do
          set_current_user(make_developer_for_space(stopped_process.space))

          put "/v2/apps/#{stopped_process.app.guid}", MultiJson.dump(state: 'STARTED')

          expect(last_response.status).to eq(400)
          expect(last_response.body).to match /Docker support has not been enabled/
          expect(decoded_response['code']).to eq(320003)
        end

        it 'does not return docker disabled message on stop' do
          set_current_user(make_developer_for_space(started_process.space))

          put "/v2/apps/#{started_process.app.guid}", MultiJson.dump(state: 'STOPPED')

          expect(last_response.status).to eq(201)
        end
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @obj_a = ProcessModelFactory.make(app: AppModel.make(space: @space_a))
        @obj_b = ProcessModelFactory.make(app: AppModel.make(space: @space_b))
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'permission enumeration', 'OrgManager',
            name:      'app',
            path:      '/v2/apps',
            enumerate: 1
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples 'permission enumeration', 'OrgUser',
            name:      'app',
            path:      '/v2/apps',
            enumerate: 0
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples 'permission enumeration', 'BillingManager',
            name:      'app',
            path:      '/v2/apps',
            enumerate: 0
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples 'permission enumeration', 'Auditor',
            name:      'app',
            path:      '/v2/apps',
            enumerate: 0
        end
      end

      describe 'App Space Level Permissions' do
        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'permission enumeration', 'SpaceManager',
            name:      'app',
            path:      '/v2/apps',
            enumerate: 1
        end

        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'permission enumeration', 'Developer',
            name:      'app',
            path:      '/v2/apps',
            enumerate: 1
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'permission enumeration', 'SpaceAuditor',
            name:      'app',
            path:      '/v2/apps',
            enumerate: 1
        end
      end
    end

    describe 'Validation messages' do
      let(:space) { process.space }
      let!(:process) { ProcessModelFactory.make(state: 'STARTED') }

      before do
        set_current_user(make_developer_for_space(space))
      end

      it 'returns duplicate app name message correctly' do
        existing_process = ProcessModel.make(app: AppModel.make(space: space))
        put "/v2/apps/#{process.app.guid}", MultiJson.dump(name: existing_process.name)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100002)
      end

      it 'returns organization quota memory exceeded message correctly' do
        space.organization.quota_definition = QuotaDefinition.make(memory_limit: 0)
        space.organization.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(memory: 128)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100005)
      end

      it 'returns space quota memory exceeded message correctly' do
        space.space_quota_definition = SpaceQuotaDefinition.make(memory_limit: 0)
        space.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(memory: 128)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310003)
      end

      it 'validates space quota memory limit before organization quotas' do
        space.organization.quota_definition = QuotaDefinition.make(memory_limit: 0)
        space.organization.save(validate: false)
        space.space_quota_definition = SpaceQuotaDefinition.make(memory_limit: 0)
        space.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(memory: 128)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310003)
      end

      it 'returns memory invalid message correctly' do
        put "/v2/apps/#{process.app.guid}", MultiJson.dump(memory: 0)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100006)
      end

      it 'returns instance memory limit exceeded error correctly' do
        space.organization.quota_definition = QuotaDefinition.make(instance_memory_limit: 100)
        space.organization.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(memory: 128)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100007)
      end

      it 'returns space instance memory limit exceeded error correctly' do
        space.space_quota_definition = SpaceQuotaDefinition.make(instance_memory_limit: 100)
        space.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(memory: 128)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310004)
      end

      it 'returns app instance limit exceeded error correctly' do
        space.organization.quota_definition = QuotaDefinition.make(app_instance_limit: 4)
        space.organization.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(instances: 5)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(100008)
      end

      it 'validates space quota instance memory limit before organization quotas' do
        space.organization.quota_definition = QuotaDefinition.make(instance_memory_limit: 100)
        space.organization.save(validate: false)
        space.space_quota_definition = SpaceQuotaDefinition.make(instance_memory_limit: 100)
        space.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(memory: 128)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310004)
      end

      it 'returns instances invalid message correctly' do
        put "/v2/apps/#{process.app.guid}", MultiJson.dump(instances: -1)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to match /instances less than 0/
        expect(decoded_response['code']).to eq(100001)
      end

      it 'returns state invalid message correctly' do
        put "/v2/apps/#{process.app.guid}", MultiJson.dump(state: 'mississippi')

        expect(last_response.status).to eq(400)
        expect(last_response.body).to match /Invalid app state provided/
        expect(decoded_response['code']).to eq(100001)
      end

      it 'validates space quota app instance limit' do
        space.space_quota_definition = SpaceQuotaDefinition.make(app_instance_limit: 2)
        space.save(validate: false)

        put "/v2/apps/#{process.app.guid}", MultiJson.dump(instances: 3)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310008)
      end
    end

    describe 'enumerate' do
      let!(:web_process) { ProcessModel.make(type: 'web') }
      let!(:other_app) { ProcessModel.make(type: 'other') }

      before do
        set_current_user_as_admin
      end

      it 'displays processes with type web' do
        get '/v2/apps'
        expect(decoded_response['total_results']).to eq(1)
        expect(decoded_response['resources'][0]['metadata']['guid']).to eq(web_process.app.guid)
      end
    end

    describe 'PUT /v2/apps/:app_guid/routes/:route_guid' do
      let(:space) { Space.make }
      let(:process) { ProcessModelFactory.make(space: space) }
      let(:route) { Route.make(space: space) }
      let(:developer) { make_developer_for_space(space) }

      before do
        set_current_user(developer)
      end

      it 'adds the route to the app' do
        expect(process.reload.routes).to be_empty

        put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil

        expect(last_response).to have_status_code(201)
        expect(process.reload.routes).to match_array([route])

        route_mapping = RouteMappingModel.last
        expect(route_mapping.app_port).to eq(8080)
        expect(route_mapping.process_type).to eq('web')
      end

      context 'when the app does not exist' do
        it 'returns 404' do
          put "/v2/apps/not-real/routes/#{route.guid}", nil
          expect(last_response).to have_status_code(404)
          expect(last_response.body).to include('AppNotFound')
        end
      end

      context 'when the route does not exist' do
        it 'returns 404' do
          put "/v2/apps/#{process.app.guid}/routes/not-real", nil
          expect(last_response).to have_status_code(404)
          expect(last_response.body).to include('RouteNotFound')
        end
      end

      context 'when the route is already mapped to the app' do
        before do
          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
        end

        it 'succeeds' do
          expect(process.reload.routes).to match_array([route])

          put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil
          expect(last_response).to have_status_code(201)
        end
      end

      context 'when the user is not a developer in the apps space' do
        before do
          set_current_user(User.make)
        end

        it 'returns 403' do
          put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil
          expect(last_response).to have_status_code(403)
        end
      end

      context 'when the route is in a different space' do
        let(:route) { Route.make }

        it 'raises an error' do
          expect(process.reload.routes).to be_empty

          put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil
          expect(last_response.status).to eq(400)
          expect(last_response.body).to include('InvalidRelation')
          expect(decoded_response['description']).to include(
            'The app cannot be mapped to this route because the route is not in this space. Apps must be mapped to routes in the same space')

          expect(process.reload.routes).to be_empty
        end
      end

      context 'when the app has multiple ports' do
        let(:process) { ProcessModelFactory.make(diego: true, space: route.space, ports: [9797, 7979]) }

        it 'uses the first port for the app as the app_port' do
          put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil
          expect(last_response.status).to eq(201)

          mapping = RouteMappingModel.last
          expect(mapping.app_port).to eq(9797)
        end
      end

      describe 'routes from tcp router groups' do
        let(:domain) { SharedDomain.make(name: 'tcp.com', router_group_guid: 'router-group-guid') }
        let(:route) { Route.make(space: process.space, domain: domain, port: 9090, host: '') }
        let(:routing_api_client) { double('routing_api_client', router_group: router_group) }
        let(:router_group) { double('router_group', type: 'tcp', guid: 'router-group-guid') }

        before do
          allow_any_instance_of(RouteValidator).to receive(:validate)
          allow(VCAP::CloudController::RoutingApi::Client).to receive(:new).and_return(routing_api_client)
        end

        it 'adds the route to the app' do
          expect(process.reload.routes).to be_empty

          put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil

          expect(last_response).to have_status_code(201)
          expect(process.reload.routes).to match_array([route])

          route_mapping = RouteMappingModel.last
          expect(route_mapping.app_port).to eq(8080)
          expect(route_mapping.process_type).to eq('web')
        end

        context 'when routing api is disabled' do
          before do
            route
            TestConfig.override(routing_api: nil)
          end

          it 'existing routes with router groups return 403 when mapped to apps' do
            put "/v2/apps/#{process.app.guid}/routes/#{route.guid}", nil
            expect(last_response).to have_status_code(403)
            expect(decoded_response['description']).to include('Routing API is disabled')
          end
        end
      end
    end

    describe 'DELETE /v2/apps/:app_guid/routes/:route_guid' do
      let(:space) { Space.make }
      let(:process) { ProcessModelFactory.make(space: space) }
      let(:route) { Route.make(space: space) }
      let!(:route_mapping) { RouteMappingModel.make(app: process.app, route: route, process_type: process.type) }
      let(:developer) { make_developer_for_space(space) }

      before do
        set_current_user(developer)
      end

      it 'removes the association' do
        expect(process.reload.routes).to match_array([route])

        delete "/v2/apps/#{process.app.guid}/routes/#{route.guid}"
        expect(last_response.status).to eq(204)

        expect(process.reload.routes).to be_empty
      end

      context 'when the app does not exist' do
        it 'returns 404' do
          delete "/v2/apps/not-found/routes/#{route.guid}"
          expect(last_response).to have_status_code(404)
          expect(last_response.body).to include('AppNotFound')
        end
      end

      context 'when the route does not exist' do
        it 'returns 404' do
          delete "/v2/apps/#{process.app.guid}/routes/not-found"
          expect(last_response).to have_status_code(404)
          expect(last_response.body).to include('RouteNotFound')
        end
      end

      context 'when the route is not mapped to the app' do
        before do
          route_mapping.destroy
        end

        it 'succeeds' do
          expect(process.reload.routes).to be_empty

          delete "/v2/apps/#{process.app.guid}/routes/#{route.guid}"
          expect(last_response).to have_status_code(204)
        end
      end

      context 'when the user is not a developer in the apps space' do
        before do
          set_current_user(User.make)
        end

        it 'returns 403' do
          delete "/v2/apps/#{process.app.guid}/routes/#{route.guid}"
          expect(last_response).to have_status_code(403)
        end
      end
    end

    describe 'GET /v2/apps/:app_guid/service_bindings' do
      let(:space) { Space.make }
      let(:managed_service_instance) { ManagedServiceInstance.make(space: space) }
      let(:developer) { make_developer_for_space(space) }
      let(:process1) { ProcessModelFactory.make(space: space, name: 'process1') }
      let(:process2) { ProcessModelFactory.make(space: space, name: 'process2') }
      let(:process3) { ProcessModelFactory.make(space: space, name: 'process3') }

      before do
        set_current_user(developer)
        ServiceBinding.make(service_instance: managed_service_instance, app: process1.app, name: 'guava')
        ServiceBinding.make(service_instance: managed_service_instance, app: process2.app, name: 'peach')
        ServiceBinding.make(service_instance: managed_service_instance, app: process3.app, name: 'cilantro')
      end

      it "queries apps' service_bindings by name" do
        # process1 has no peach bindings
        get "/v2/apps/#{process1.app.guid}/service_bindings?q=name:peach"
        expect(last_response.status).to eql(200), last_response.body
        service_bindings = decoded_response['resources']
        expect(service_bindings.size).to eq(0)

        get "/v2/apps/#{process1.app.guid}/service_bindings?q=name:guava"
        expect(last_response.status).to eql(200), last_response.body
        service_bindings = decoded_response['resources']
        expect(service_bindings.size).to eq(1)
        entity = service_bindings[0]['entity']
        expect(entity['app_guid']).to eq(process1.app.guid)
        expect(entity['service_instance_guid']).to eq(managed_service_instance.guid)
        expect(entity['name']).to eq('guava')

        [[process1, 'guava'], [process2, 'peach'], [process3, 'cilantro']].each do |process, fruit|
          get "/v2/apps/#{process.app.guid}/service_bindings?q=name:#{fruit}"
          expect(last_response.status).to eql(200)
          service_bindings = decoded_response['resources']
          expect(service_bindings.size).to eq(1)
          entity = service_bindings[0]['entity']
          expect(entity['app_guid']).to eq(process.app.guid)
          expect(entity['service_instance_guid']).to eq(managed_service_instance.guid)
          expect(entity['name']).to eq(fruit)
        end
      end

      # This is why there isn't much point testing lookup by name with this endpoint --
      # These tests show we can have at most one hit per name in the
      # apps/APPGUID/service_bindings endpoint.
      context 'when there are multiple services' do
        let(:si1) { ManagedServiceInstance.make(space: space) }
        let(:si2) { ManagedServiceInstance.make(space: space) }
        let(:developer) { make_developer_for_space(space) }
        let(:process1) { ProcessModelFactory.make(space: space, name: 'process1') }
        let(:process2) { ProcessModelFactory.make(space: space, name: 'process2') }

        before do
          set_current_user(developer)
          ServiceBinding.make(service_instance: si1, app: process1.app, name: 'out')
          ServiceBinding.make(service_instance: si2, app: process2.app, name: 'free')
        end

        it 'binding si2 to process1 with a name in use by process1 is not ok' do
          expect {
            ServiceBinding.make(service_instance: si2, app: process1.app, name: 'out')
          }.to raise_error(Sequel::ValidationFailed, /App binding names must be unique\./)
        end

        it 'binding si1 to process1 with a new name is not ok' do
          expect {
            ServiceBinding.make(service_instance: si1, app: process1.app, name: 'gravy')
          }.to raise_error(Sequel::ValidationFailed, 'The app is already bound to the service.')
        end

        it 'binding si2 to process1 with a name in use by process2 is ok' do
          ServiceBinding.make(service_instance: si2, app: process1.app, name: 'free')
          get "/v2/apps/#{process1.app.guid}/service_bindings?results-per-page=2&page=1&q=name:free"
          expect(last_response.status).to eq(200), last_response.body
        end
      end
    end

    describe 'DELETE /v2/apps/:app_guid/service_bindings/:service_binding_guid' do
      let(:space) { Space.make }
      let(:process) { ProcessModelFactory.make(space: space) }
      let(:instance) { ManagedServiceInstance.make(space: space) }
      let!(:service_binding) { ServiceBinding.make(app: process.app, service_instance: instance) }
      let(:developer) { make_developer_for_space(space) }

      before do
        set_current_user(developer)
        allow_any_instance_of(VCAP::Services::ServiceBrokers::V2::Client).to receive(:unbind)
      end

      it 'removes the association' do
        expect(process.reload.service_bindings).to match_array([service_binding])

        delete "/v2/apps/#{process.app.guid}/service_bindings/#{service_binding.guid}"
        expect(last_response.status).to eq(204)

        expect(process.reload.service_bindings).to be_empty
      end

      it 'has the deprecated warning header' do
        delete "/v2/apps/not-found/service_bindings/#{service_binding.guid}"
        expect(last_response).to be_a_deprecated_response
      end

      context 'when the app does not exist' do
        it 'returns 404' do
          delete "/v2/apps/not-found/service_bindings/#{service_binding.guid}"
          expect(last_response).to have_status_code(404)
          expect(last_response.body).to include('AppNotFound')
        end
      end

      context 'when the service binding does not exist' do
        it 'returns 404' do
          delete "/v2/apps/#{process.app.guid}/service_bindings/not-found"
          expect(last_response).to have_status_code(404)
          expect(last_response.body).to include('ServiceBindingNotFound')
        end
      end

      context 'when the user is not a developer in the apps space' do
        before do
          set_current_user(User.make)
        end

        it 'returns 403' do
          delete "/v2/apps/#{process.app.guid}/service_bindings/#{service_binding.guid}"
          expect(last_response).to have_status_code(403)
        end
      end
    end

    describe 'GET /v2/apps/:guid/permissions' do
      let(:process) { ProcessModelFactory.make(space: space) }
      let(:space) { Space.make }
      let(:user) { User.make }

      before do
        space.organization.add_user(user)
      end

      context 'when the user is a SpaceDeveloper' do
        before do
          space.add_developer(user)
          set_current_user(user, { scopes: ['cloud_controller.user'] })
        end

        it 'succeeds and present data reading permissions' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(200)
          expect(parsed_response['read_sensitive_data']).to eq(true)
          expect(parsed_response['read_basic_data']).to eq(true)
        end
      end

      context 'when the user is a OrgManager' do
        before do
          process.organization.add_manager(user)
          set_current_user(user, { scopes: ['cloud_controller.user'] })
        end

        it 'succeeds and present data reading permissions' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(200)
          expect(parsed_response['read_sensitive_data']).to eq(false)
          expect(parsed_response['read_basic_data']).to eq(true)
        end
      end

      context 'when the user is a BillingManager' do
        before do
          space.organization.add_billing_manager(user)
          set_current_user(user, { scopes: ['cloud_controller.user'] })
        end

        it 'fails with a 403' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(403)
          expect(decoded_response['code']).to eq(10003)
          expect(decoded_response['error_code']).to eq('CF-NotAuthorized')
          expect(decoded_response['description']).to include('You are not authorized to perform the requested action')
        end
      end

      context 'when the user is a OrgAuditor' do
        before do
          space.organization.add_auditor(user)
          set_current_user(user, { scopes: ['cloud_controller.user'] })
        end

        it 'fails with a 403' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(403)
          expect(decoded_response['code']).to eq(10003)
          expect(decoded_response['error_code']).to eq('CF-NotAuthorized')
          expect(decoded_response['description']).to include('You are not authorized to perform the requested action')
        end
      end

      context 'when the user is a SpaceManager' do
        before do
          space.add_manager(user)
          set_current_user(user, { scopes: ['cloud_controller.user'] })
        end

        it 'succeeds and present data reading permissions' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(200)
          expect(parsed_response['read_sensitive_data']).to eq(false)
          expect(parsed_response['read_basic_data']).to eq(true)
        end
      end

      context 'when the user is a SpaceAuditor' do
        before do
          space.add_auditor(user)
          set_current_user(user, { scopes: ['cloud_controller.user'] })
        end

        it 'succeeds and present data reading permissions' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(200)
          expect(parsed_response['read_sensitive_data']).to eq(false)
          expect(parsed_response['read_basic_data']).to eq(true)
        end
      end

      context 'when missing cloud_controller.user scope' do
        let(:user) { make_developer_for_space(space) }

        before do
          set_current_user(user, { scopes: [] })
        end

        it 'returns 403' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(403)
        end
      end

      context 'when the user is not part of the org or space' do
        before do
          new_user = User.make
          set_current_user(new_user)
        end

        it 'returns 403' do
          get "/v2/apps/#{process.app.guid}/permissions"
          expect(last_response.status).to eq(403)
          expect(decoded_response['code']).to eq(10003)
          expect(decoded_response['error_code']).to eq('CF-NotAuthorized')
          expect(decoded_response['description']).to include('You are not authorized to perform the requested action')
        end
      end

      context 'when the app does not exist' do
        it 'returns 404' do
          get '/v2/apps/made-up-guid/permissions'
          expect(last_response.status).to eq(404)
        end
      end
    end
  end
end
