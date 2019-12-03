require 'spec_helper'

RSpec.describe 'Space Manifests' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make }
  let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
  let(:route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space, host: 'a_host') }
  let(:second_route) {
    VCAP::CloudController::Route.make(domain: shared_domain, space: space, path: '/path', host: 'b_host')
  }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/spaces/:guid/actions/apply_manifest' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
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
              service_instance.name
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
              service_instance.name
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
      stub_bind(service_instance)
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

      expect(app1_model.service_bindings.length).to eq 1
      expect(app1_model.service_bindings.first.service_instance).to eq service_instance
      expect(app1_model.labels.map { |label| { key: label.key_name, value: label.value } }).
        to match_array([{ key: 'potato', value: 'yam' }, { key: 'songs', value: 'missing' }])
      expect(app1_model.annotations.map { |a| { key: a.key, value: a.value } }).
        to match_array([{ key: 'potato', value: 'idaho' }, { key: 'juice', value: 'newton' }])

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
      expect(app2_model.service_bindings.first.service_instance).to eq service_instance
      expect(app2_model.labels.map { |label| { key: label.key_name, value: label.value } }).
        to match_array([{ key: 'potato', value: 'yam' },])
      expect(app2_model.annotations.map { |a| { key: a.key, value: a.value } }).
        to match_array([{ key: 'potato', value: 'idaho' }, { key: 'juice', value: 'newton' },])
    end

    context 'service bindings' do
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: {}) }

      it 'returns an appropriate error when fail to bind' do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:bind).and_raise('Failed')

        post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
        Delayed::Worker.new.work_off

        job_location = last_response.headers['Location']
        get job_location, nil, user_header
        parsed_response = MultiJson.load(last_response.body)

        expect(VCAP::CloudController::ServiceBinding.count).to eq(0)
        expect(parsed_response['errors'].first['detail']).to eq("For application '#{app1_model.name}': For service '#{service_instance.name}': Failed")
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
                service_instance.name
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
                service_instance.name
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
        expect(new_app.service_bindings.first.service_instance).to eq service_instance
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

    context 'when the app name is non-conformant (bad!)' do
      let(:app1_model) { VCAP::CloudController::AppModel.make(name: '/!/invalid', space: space) }
      let(:yml_manifest) do
        {
          'applications' => [
            { 'name' => app1_model.name },
          ]
        }.to_yaml
      end

      it 'returns a 422 with an informative message' do
        expect {
          post "/v3/spaces/#{space.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'].first['detail']).to match(
            /"\/!\/invalid" must contain only alphanumeric characters, "_", or "-" when routes are not present/)
        }.to change { VCAP::CloudController::AppModel.count }.by(0)
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
                service_instance.name
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
  end
end
