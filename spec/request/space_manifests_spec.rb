require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Space Manifests' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make }
  let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
  let(:route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space, host: 'a_host') }
  let(:second_route) {
    VCAP::CloudController::Route.make(domain: shared_domain, space: space, path: '/path', host: 'b_host')
  }

  describe 'POST /v3/spaces/:guid/actions/apply_manifest' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:service_instance_1) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:service_instance_2) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:binding_name) { Sham.name }
    let(:app1_model) { VCAP::CloudController::AppModel.make(name: 'Tryggvi', space: space) }
    let!(:process1) { VCAP::CloudController::ProcessModel.make(app: app1_model) }
    let(:app2_model) { VCAP::CloudController::AppModel.make(name: 'Sigurlaug', space: space) }
    let!(:process2) { VCAP::CloudController::ProcessModel.make(app: app2_model) }
    let(:yml_manifest) do
      {
        'applications' => [
          { 'name' => app1_model.name,
            'instances' => 4,
            'memory' => '2048MB',
            'disk_quota' => '1.5GB',
            'buildpack' => buildpack.name,
            'stack' => buildpack.stack,
            'command' => 'new-command',
            'health_check_type' => 'http',
            'health_check_http_endpoint' => '/health',
            'timeout' => 42,
            'env' => {
              'k1' => 'mangos',
              'k2' => 'pears',
              'k3' => 'watermelon'
            },
            'routes' => [
              { 'route' => "https://#{route.host}.#{route.domain.name}" },
              { 'route' => "https://#{second_route.host}.#{second_route.domain.name}/path" }
            ],
            'services' => [
              service_instance_1.name,
              {
                'name' => service_instance_2.name,
                'parameters' => { 'foo' => 'bar' },
                'binding_name' => binding_name
              }
            ],
            'metadata' => {
              'annotations' => {
                'potato' => 'idaho',
                'juice' => 'newton',
                'berry' => nil,
              },
              'labels' => {
                'potato' => 'yam',
                'downton' => nil,
                'myspace.com/songs' => 'missing',
              },
            },
          },
          { 'name' => app2_model.name,
            'instances' => 3,
            'memory' => '2048MB',
            'disk_quota' => '1.5GB',
            'buildpack' => buildpack.name,
            'stack' => buildpack.stack,
            'command' => 'newer-command',
            'health_check_type' => 'http',
            'health_check_http_endpoint' => '/health',
            'timeout' => 42,
            'env' => {
              'k1' => 'cucumber',
              'k2' => 'radish',
              'k3' => 'fleas'
            },
            'routes' => [
              { 'route' => "https://#{route.host}.#{route.domain.name}" },
              { 'route' => "https://#{second_route.host}.#{second_route.domain.name}/path" }
            ],
            'services' => [
              service_instance_1.name
            ],
            'metadata' => {
              'annotations' => {
                'potato' => 'idaho',
                'juice' => 'newton',
                'berry' => nil,
              },
              'labels' => {
                'potato' => 'yam',
                'downton' => nil,
              },
            },
          }
        ]
      }.to_yaml
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      TestConfig.override(kubernetes: {})

      stub_bind(service_instance_1)
      stub_bind(service_instance_2)
      VCAP::CloudController::LabelsUpdate.update(app1_model, { 'potato' => 'french',
                                                               'downton' => 'abbey road', }, VCAP::CloudController::AppLabelModel)
      VCAP::CloudController::AnnotationsUpdate.update(app1_model, { 'potato' => 'baked',
        'berry' => 'white', }, VCAP::CloudController::AppAnnotationModel)
    end

    it 'applies the manifest' do
      web_process = app1_model.web_processes.first
      expect(web_process.instances).to eq(1)
      post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

      expect(last_response.status).to eq(202)
      job_guid = VCAP::CloudController::PollableJobModel.last.guid
      expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

      Delayed::Worker.new.work_off
      expect(VCAP::CloudController::PollableJobModel.find(guid: job_guid)).to be_complete, VCAP::CloudController::PollableJobModel.find(guid: job_guid).cf_api_error

      web_process.reload
      expect(web_process.instances).to eq(4)
      expect(web_process.memory).to eq(2048)
      expect(web_process.disk_quota).to eq(1536)
      expect(web_process.command).to eq('new-command')
      expect(web_process.health_check_type).to eq('http')
      expect(web_process.health_check_http_endpoint).to eq('/health')
      expect(web_process.health_check_timeout).to eq(42)

      app1_model.reload
      lifecycle_data = app1_model.lifecycle_data
      expect(lifecycle_data.buildpacks).to include(buildpack.name)
      expect(lifecycle_data.stack).to eq(buildpack.stack)
      expect(app1_model.environment_variables).to match(
        'k1' => 'mangos',
        'k2' => 'pears',
        'k3' => 'watermelon'
      )
      expect(app1_model.routes).to match_array([route, second_route])

      expect(app1_model.service_bindings.map(&:service_instance)).to contain_exactly(service_instance_1, service_instance_2)
      expect(service_instance_1.service_bindings.first.name).to be_nil
      expect(service_instance_2.service_bindings.first.name).to eq(binding_name)
      expect(app1_model).to have_labels({ key: 'potato', value: 'yam' }, { prefix: 'myspace.com', key: 'songs', value: 'missing' })
      expect(app1_model).to have_annotations({ key: 'potato', value: 'idaho' }, { key: 'juice', value: 'newton' })

      app2_model.reload
      lifecycle_data = app2_model.lifecycle_data
      expect(lifecycle_data.buildpacks).to include(buildpack.name)
      expect(lifecycle_data.stack).to eq(buildpack.stack)
      expect(app2_model.environment_variables).to match(
        'k1' => 'cucumber',
        'k2' => 'radish',
        'k3' => 'fleas'
      )
      expect(app2_model.routes).to match_array([route, second_route])

      expect(app2_model.service_bindings.length).to eq 1
      expect(app2_model.service_bindings.first.service_instance).to eq service_instance_1
      expect(app2_model).to have_labels(
        { key: 'potato', value: 'yam' }
      )
      expect(app2_model).to have_annotations(
        { key: 'potato', value: 'idaho' }, { key: 'juice', value: 'newton' }
      )
    end

    context 'service bindings' do
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: {}) }

      it 'returns an appropriate error when fail to bind' do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:bind).and_raise('Failed')
        allow(client).to receive(:unbind).and_return({ async: false })

        post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
        Delayed::Worker.new.work_off

        job_location = last_response.headers['Location']
        get job_location, nil, user_header
        parsed_response = MultiJson.load(last_response.body)

        expect(VCAP::CloudController::ServiceBinding.count).to eq(0)
        expect(parsed_response['errors'].first['detail']).to eq("For application '#{app1_model.name}': For service '#{service_instance_1.name}': Failed")
      end
    end

    context 'when one of the apps does not exist' do
      let!(:yml_manifest) do
        {
          'applications' => [
            { 'name' => app1_model.name,
              'instances' => 4,
              'memory' => '2048MB',
              'disk_quota' => '1.5GB',
              'buildpack' => buildpack.name,
              'stack' => buildpack.stack,
              'command' => 'new-command',
              'health_check_type' => 'http',
              'health_check_http_endpoint' => '/health',
              'timeout' => 42,
              'env' => {
                'k1' => 'mangos',
                'k2' => 'pears',
                'k3' => 'watermelon'
              },
              'routes' => [
                { 'route' => "https://#{route.host}.#{route.domain.name}" },
                { 'route' => "https://#{second_route.host}.#{second_route.domain.name}/path" }
              ],
              'services' => [
                service_instance_1.name
              ]
            },
            { 'name' => 'some-other-app',
              'instances' => 4,
              'memory' => '2048MB',
              'disk_quota' => '1.5GB',
              'buildpack' => buildpack.name,
              'stack' => buildpack.stack,
              'command' => 'new-command',
              'health_check_type' => 'http',
              'health_check_http_endpoint' => '/health',
              'timeout' => 42,
              'env' => {
                'k1' => 'mangos',
                'k2' => 'pears',
                'k3' => 'watermelon'
              },
              'services' => [
                service_instance_1.name
              ]
            }
          ]
        }.to_yaml
      end

      it 'creates the app' do
        expect {
          post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
          expect(last_response.status).to eq(202), last_response.body
        }.to change { VCAP::CloudController::AppModel.count }.by(1)

        job_guid = VCAP::CloudController::PollableJobModel.last.guid
        expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

        Delayed::Worker.new.work_off
        expect(VCAP::CloudController::PollableJobModel.find(guid: job_guid)).to be_complete, VCAP::CloudController::PollableJobModel.find(guid: job_guid).cf_api_error

        new_app = VCAP::CloudController::AppModel.last
        web_process = new_app.web_processes.first

        expect(web_process.instances).to eq(4)
        expect(web_process.memory).to eq(2048)
        expect(web_process.disk_quota).to eq(1536)
        expect(web_process.command).to eq('new-command')
        expect(web_process.health_check_type).to eq('http')
        expect(web_process.health_check_http_endpoint).to eq('/health')
        expect(web_process.health_check_timeout).to eq(42)

        new_app.reload
        lifecycle_data = new_app.lifecycle_data
        expect(lifecycle_data.buildpacks).to include(buildpack.name)
        expect(lifecycle_data.stack).to eq(buildpack.stack)
        expect(new_app.environment_variables).to match(
          'k1' => 'mangos',
          'k2' => 'pears',
          'k3' => 'watermelon'
        )

        expect(new_app.service_bindings.length).to eq 1
        expect(new_app.service_bindings.first.service_instance).to eq service_instance_1
      end
    end

    context 'when there is an existing app with Docker lifecycle-type' do
      let!(:docker_route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space) }
      let!(:docker_app) { VCAP::CloudController::AppModel.make(:docker, name: 'docker-app', space: space) }
      let!(:yml_manifest) do
        {
          'applications' => [
            {
              'name' => docker_app.name,
              'routes' => [
                { 'route' => "https://#{docker_route.host}.#{docker_route.domain.name}" },
              ],
            }
          ]
        }.to_yaml
      end

      it 'maps the new route to the app without a port specified' do
        post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
        expect(last_response.status).to eq(202), last_response.body

        job_guid = VCAP::CloudController::PollableJobModel.last.guid
        expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

        Delayed::Worker.new.work_off
        expect(VCAP::CloudController::PollableJobModel.find(guid: job_guid)).to be_complete, VCAP::CloudController::PollableJobModel.find(guid: job_guid).cf_api_error

        expect(docker_app.buildpack?).to be false

        app_destinations = VCAP::CloudController::RouteMappingModel.where(app: docker_app).all
        expect(app_destinations.first.app_port).to eq(
          VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED
        )
      end
    end

    context 'when the app name is not a valid host name and the default-route flag is set to true' do
      let(:app1_model) { VCAP::CloudController::AppModel.make(name: 'a' * 64, space: space) }
      let(:yml_manifest) do
        {
          'applications' => [
            { 'name' => app1_model.name,
              'default-route' => true },
          ]
        }.to_yaml
      end

      it 'returns a 202 but fails on the job' do
        expect {
          post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
        }.to change { VCAP::CloudController::AppModel.count }.by(0)

        expect(last_response).to have_status_code(202)
        expect(last_response.status).to eq(202), last_response.body

        job_guid = VCAP::CloudController::PollableJobModel.last.guid
        expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

        Delayed::Worker.new.work_off
        job = VCAP::CloudController::PollableJobModel.find(guid: job_guid)
        errors = YAML.safe_load(job.cf_api_error)['errors']
        expect(errors.length).to eq 1
        expect(errors[0]['detail']).to include('Host cannot exceed 63 characters')
      end

      context 'and routes are provided in the manifest' do
        let(:yml_manifest) do
          {
            'applications' => [
              { 'name' => app1_model.name,
                'default-route' => true,
                'routes' => [{ 'route' => "http://#{route.host}.#{shared_domain.name}" }] },
            ]
          }.to_yaml
        end

        it 'returns a 202 and succeeds' do
          expect {
            post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
          }.to change { VCAP::CloudController::AppModel.count }.by(0)

          expect(last_response).to have_status_code(202)
          expect(last_response.status).to eq(202), last_response.body

          job_guid = VCAP::CloudController::PollableJobModel.last.guid
          expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

          Delayed::Worker.new.work_off
          job = VCAP::CloudController::PollableJobModel.find(guid: job_guid)
          expect(job.complete?).to be true
          expect(job.cf_api_error).to be nil
        end
      end
    end

    context 'when the version key is included' do
      context 'when the version is supported' do
        let(:yml_manifest) do
          {
            'version' => 1,
            'applications' => [
              { 'name' => app1_model.name },
            ]
          }.to_yaml
        end

        it 'applies the manifest' do
          post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

          expect(last_response.status).to eq(202)
        end
      end

      context 'when the version is not supported' do
        let(:yml_manifest) do
          {
            'version' => 2,
            'applications' => [
              { 'name' => app1_model.name },
            ]
          }.to_yaml
        end

        it 'returns a 422' do
          post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Unsupported manifest schema version. Currently supported versions: [1].')
        end
      end
    end

    describe 'audit events' do
      let!(:process1) { nil }

      let(:yml_manifest) do
        {
          'applications' => [
            { 'name' => app1_model.name,
              'instances' => 4,
              'memory' => '2048MB',
              'disk_quota' => '1.5GB',
              'buildpack' => buildpack.name,
              'stack' => buildpack.stack,
              'command' => 'new-command',
              'health_check_type' => 'http',
              'health_check_http_endpoint' => '/health',
              'timeout' => 42,
              'env' => {
                'k1' => 'mangos',
                'k2' => 'pears',
                'k3' => 'watermelon'
              },
              'routes' => [
                { 'route' => "https://#{route.host}.#{route.domain.name}" },
                { 'route' => "https://pants.#{second_route.domain.name}/path" }
              ],
              'services' => [
                service_instance_1.name
              ]
            }
          ]
        }.to_yaml
      end

      it 'creates audit events tagged with metadata.manifest_triggered' do
        expect {
          post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
          Delayed::Worker.new.work_off
        }.to change { VCAP::CloudController::Event.count }.by 10

        manifest_triggered_events = VCAP::CloudController::Event.find_all { |event| event.metadata['manifest_triggered'] }
        expect(manifest_triggered_events.map(&:type)).to match_array([
          'audit.app.process.update',
          'audit.app.process.create',
          'audit.app.process.scale',
          'audit.app.update',
          'audit.app.update',
          'audit.app.map-route',
          'audit.route.create',
          'audit.app.map-route',
          'audit.service_binding.create',
        ])

        other_events = VCAP::CloudController::Event.find_all { |event| !event.metadata['manifest_triggered'] }
        expect(other_events.map(&:type)).to eq(['audit.app.apply_manifest',])
      end
    end

    context 'yaml anchors' do
      let(:yml_manifest) do
        <<~YML
          ---
          applications:
          - name: blah
            processes:
            - type: web
              memory: &default_value 321M
              disk_quota: *default_value
        YML
      end

      it 'does NOT accept yaml with anchors' do
        post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

        expect(last_response.status).to eq(400)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['errors'].first['detail']).to eq('Bad request: Manifest does not support Anchors and Aliases')
      end
    end
  end

  describe 'POST /v3/spaces/:guid/manifest_diff' do
    let(:api_call) { lambda { |user_headers| post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, yml_headers(user_headers) } }

    let(:org) { space.organization }
    let(:app1_model) { VCAP::CloudController::AppModel.make(name: 'app-1', space: space) }
    let!(:process1) { VCAP::CloudController::ProcessModel.make(app: app1_model) }
    let!(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app1_model, process_type: process1.type, route: route) }
    let(:default_manifest) do
      {
        'applications' => [
          {
            'name' => app1_model.name,
            'stack' => process1.stack.name,
            'routes' => [
              {
                'route' => "a_host.#{shared_domain.name}"
              }
            ],
            'processes' => [
              {
                'type' => process1.type,
                'instances' => process1.instances,
                'memory' => '1024M',
                'disk_quota' => '1024M',
                'health-check-type' =>  process1.health_check_type
              }
            ]
          },
        ]
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new(code: 403)
      h['org_auditor'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
      h['no_role'] = { code: 404 }

      h['admin'] = {
        code: 201,
        response_object: diff_json
      }

      h['space_developer'] = {
        code: 201,
        response_object: diff_json
      }

      h.freeze
    end

    context 'when a v2 manifest has a change to the web process' do
      let(:diff_json) do
        {
          diff: a_collection_containing_exactly(
            { op: 'replace', path: '/applications/0/memory', was: '1024M', value: '256M' },
            { op: 'replace', path: '/applications/0/disk-quota', was: '1024M', value: '2048M' },
          )
        }
      end

      let(:yml_manifest) do
        {
          'applications' => [
            {
              'name' => app1_model.name,
              'memory' => '256M',
              'disk-quota' => '2G',
            }
          ]
        }.to_yaml
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when there are changes in the manifest' do
      let(:diff_json) do
        {
          diff: a_collection_containing_exactly(
            { op: 'replace', path: '/applications/0/stack', was: process1.stack.name, value: 'big brother' },
            { op: 'add', path: '/applications/0/services', value: [
              'service-without-name-label',
              { name: 'service1',
                parameters: { foo: 'bar' }
              }
            ] },
          )
        }
      end

      let(:yml_manifest) do
        default_manifest['applications'][0]['new-key'] = 'hoh'
        default_manifest['applications'][0]['stack'] = 'big brother'
        default_manifest['applications'][0]['services'] = [
          'service-without-name-label',
          { 'name' => 'service1',
            'parameters' => { 'foo' => 'bar' }
          }
        ]
        default_manifest.to_yaml
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the request is invalid' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      context 'when there is a manifest without \'applications\'' do
        let(:yml_manifest) do
          {
            'not-applications' => [
              {
                'name' => 'new-app',
              },
            ]
          }.to_yaml
        end

        it 'returns an appropriate error' do
          post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, yml_headers(user_header)
          parsed_response = MultiJson.load(last_response.body)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors'].first['detail']).to eq("Cannot parse manifest with no 'applications' field.")
        end
      end

      context 'the manifest is unparseable' do
        let(:yml_manifest) do
          {
            'key' => 'this is json, not yaml'
          }
        end

        it 'returns an appropriate error' do
          post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, yml_headers(user_header)
          parsed_response = MultiJson.load(last_response.body)

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'].first['detail']).to eq('Request invalid due to parse error: invalid request body')
        end
      end

      context 'the manifest is a not supported version' do
        let(:yml_manifest) do
          {
            'version' => 1234567,
            'applications' => [
              {
                'name' => 'new-app',
              },
            ]
          }.to_yaml
        end

        it 'returns an appropriate error' do
          post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, yml_headers(user_header)
          parsed_response = MultiJson.load(last_response.body)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors'].first['detail']).to eq('Unsupported manifest schema version. Currently supported versions: [1].')
        end
      end

      context 'the content-type is omitted' do
        let(:yml_manifest) do
          {
            'applications' => [
              {
                'name' => 'new-app',
              },
            ]
          }.to_yaml
        end

        it 'returns an appropriate error' do
          headers = yml_headers(user_header)
          headers.delete('CONTENT_TYPE')
          post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, headers
          parsed_response = MultiJson.load(last_response.body)

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'].first['detail']).to eq('Bad request: Content-Type must be yaml')
        end
      end

      context 'the content-type is not yaml' do
        let(:yml_manifest) do
          {
            'applications' => [
              {
                'name' => 'new-app',
              },
            ]
          }.to_yaml
        end

        it 'returns an appropriate error' do
          headers = yml_headers(user_header)
          headers['CONTENT_TYPE'] = 'bogus'

          post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, headers
          parsed_response = MultiJson.load(last_response.body)

          expect(last_response).to have_status_code(400)
          expect(parsed_response['errors'].first['detail']).to eq('Bad request: Content-Type must be yaml')
        end
      end

      context 'when there is a field with an invalid type' do
        let(:yml_manifest) do
          {
            'applications' => [
              {
                'name' => 'new-app',
                'stack' => { 'hash' => 'but should be a string' }
              },
            ]
          }.to_yaml
        end

        it 'returns an appropriate error' do
          post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, yml_headers(user_header)
          parsed_response = MultiJson.load(last_response.body)

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors'].first['detail']).to eq("For application 'new-app': Stack must be a string")
        end
      end
    end

    context 'the space does not exist' do
      let(:yml_manifest) do
        {
          'applications' => [
            {
              'name' => 'new-app',
            },
          ]
        }.to_yaml
      end

      it 'returns an appropriate error' do
        post '/v3/spaces/not-space-guid/manifest_diff', yml_manifest, yml_headers(user_header)

        expect(last_response).to have_status_code(404)
      end
    end

    context 'yaml anchors' do
      let(:yml_manifest) do
        <<~YML
          ---
          applications:
          - name: blah
            processes:
            - type: web
              memory: &default_value 321M
              disk_quota: *default_value
        YML
      end

      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'does NOT accept yaml with anchors' do
        post "/v3/spaces/#{space.guid}/manifest_diff", yml_manifest, yml_headers(user_header)

        expect(last_response.status).to eq(400)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['errors'].first['detail']).to eq('Bad request: Manifest does not support Anchors and Aliases')
      end
    end
  end
end
