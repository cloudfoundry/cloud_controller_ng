require 'spec_helper'

RSpec.describe 'App Manifests' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { FactoryBot.create(:space) }
  let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
  let(:route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space, host: 'a_host') }
  let(:second_route) {
    VCAP::CloudController::Route.make(domain: shared_domain, space: space, path: '/path', host: 'b_host')
  }
  let(:app_model) { FactoryBot.create(:app, :buildpack, space: space) }

  let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/apps/:guid/actions/apply_manifest' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:yml_manifest) do
      {
        'applications' => [
          { 'name' => 'blah',
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
          }
        ]
      }.to_yaml
    end

    before do
      stub_bind(service_instance)
    end

    it 'applies the manifest' do
      web_process = app_model.web_processes.first
      expect(web_process.instances).to eq(1)

      post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

      expect(last_response.status).to eq(202)
      job_guid = VCAP::CloudController::PollableJobModel.last.guid
      expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

      Delayed::Worker.new.work_off
      expect(VCAP::CloudController::PollableJobModel.find(guid: job_guid)).to be_complete

      web_process.reload
      expect(web_process.instances).to eq(4)
      expect(web_process.memory).to eq(2048)
      expect(web_process.disk_quota).to eq(1536)
      expect(web_process.command).to eq('new-command')
      expect(web_process.health_check_type).to eq('http')
      expect(web_process.health_check_http_endpoint).to eq('/health')
      expect(web_process.health_check_timeout).to eq(42)

      app_model.reload
      lifecycle_data = app_model.lifecycle_data
      expect(lifecycle_data.buildpacks).to include(buildpack.name)
      expect(lifecycle_data.stack).to eq(buildpack.stack)
      expect(app_model.environment_variables).to match(
        'k1' => 'mangos',
        'k2' => 'pears',
        'k3' => 'watermelon'
      )
      expect(app_model.routes).to match_array([route, second_route])

      expect(app_model.service_bindings.length).to eq 1
      expect(app_model.service_bindings.first.service_instance).to eq service_instance
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

      it 'accepts yaml with anchors' do
        post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

        expect(last_response.status).to eq(202)
        job_guid = VCAP::CloudController::PollableJobModel.last.guid
        expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

        Delayed::Worker.new.work_off
        expect(VCAP::CloudController::PollableJobModel.find(guid: job_guid)).to be_complete

        web_process = app_model.web_processes.first
        expect(web_process.memory).to eq(321)
        expect(web_process.disk_quota).to eq(321)
      end
    end

    describe 'audit events' do
      let!(:process) { nil }

      let(:yml_manifest) do
        {
          'applications' => [
            { 'name' => 'blah',
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
          post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
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

      context 'when no-route is included and the app has existing routes' do
        let(:yml_manifest) do
          {
            'applications' => [
              { 'name' => 'blah',
                'no-route' => true,
              }
            ]
          }.to_yaml
        end

        before do
          VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route)
        end

        it 'creates audit.app.unmap-route audit events including metadata.manifest_triggered' do
          expect {
            post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
            Delayed::Worker.new.work_off
          }.to change { VCAP::CloudController::Event.count }.by 4

          manifest_triggered_events = VCAP::CloudController::Event.find_all { |event| event.metadata['manifest_triggered'] }
          expect(manifest_triggered_events.map(&:type)).to match_array([
            'audit.app.update',
            'audit.app.update',
            'audit.app.unmap-route',
          ])

          other_events = VCAP::CloudController::Event.find_all { |event| !event.metadata['manifest_triggered'] }
          expect(other_events.map(&:type)).to eq(['audit.app.apply_manifest',])
        end
      end
    end

    describe 'no-route' do
      let(:yml_manifest) do
        {
          'applications' => [
            { 'name' => 'blah',
              'no-route' => true,
            }
          ]
        }.to_yaml
      end
      let!(:route_mapping) do
        VCAP::CloudController::RouteMappingModel.make(
          app: app_model,
          route: route,
          process_type: process.type
        )
      end

      it 'deletes the existing route' do
        expect(app_model.routes).to match_array([route])

        post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

        expect(last_response.status).to eq(202)
        job_guid = VCAP::CloudController::PollableJobModel.last.guid
        expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

        Delayed::Worker.new.work_off
        expect(VCAP::CloudController::PollableJobModel.find(guid: job_guid)).to be_complete

        app_model.reload
        expect(app_model.routes).to be_empty
      end
    end

    describe 'multiple processes' do
      let(:web_process) do
        {
          'type' => 'web',
          'instances' => 4,
          'command' => 'new-command',
          'memory' => '2048MB',
          'disk_quota' => '256MB',
          'health-check-type' => 'http',
          'health-check-http-endpoint' => '/test',
          'timeout' => 10,
        }
      end

      let(:worker_process) do
        {
          'type' => 'worker',
          'instances' => 2,
          'command' => 'bar',
          'memory' => '512MB',
          'disk_quota' => '1024M',
          'health-check-type' => 'port',
          'timeout' => 150
        }
      end

      let(:yml_manifest) do
        {
          'applications' => [
            {
              'name' => 'blah',
              'processes' => [web_process, worker_process]
            }
          ]
        }.to_yaml
      end

      context 'when all the process types already exist' do
        let!(:process2) { VCAP::CloudController::ProcessModel.make(app: app_model, type: 'worker') }

        it 'applies the manifest' do
          web_process = app_model.web_processes.first
          expect(web_process.instances).to eq(1)

          post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

          expect(last_response.status).to eq(202)
          job_guid = VCAP::CloudController::PollableJobModel.last.guid
          expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

          Delayed::Worker.new.work_off
          background_job = VCAP::CloudController::PollableJobModel.find(guid: job_guid)
          expect(background_job).to be_complete, "Failed due to: #{background_job.cf_api_error}"

          web_process.reload
          expect(web_process.instances).to eq(4)
          expect(web_process.memory).to eq(2048)
          expect(web_process.disk_quota).to eq(256)
          expect(web_process.command).to eq('new-command')
          expect(web_process.health_check_type).to eq('http')
          expect(web_process.health_check_http_endpoint).to eq('/test')
          expect(web_process.health_check_timeout).to eq(10)

          process2.reload
          expect(process2.instances).to eq(2)
          expect(process2.memory).to eq(512)
          expect(process2.disk_quota).to eq(1024)
          expect(process2.command).to eq('bar')
          expect(process2.health_check_type).to eq('port')
          expect(process2.health_check_timeout).to eq(150)
        end
      end

      context 'when some of the process types do NOT exist for the app yet' do
        it 'creates the processes and applies the manifest' do
          web_process = app_model.web_processes.first
          expect(web_process.instances).to eq(1)

          post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

          expect(last_response.status).to eq(202)
          job_guid = VCAP::CloudController::PollableJobModel.last.guid
          expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

          Delayed::Worker.new.work_off
          background_job = VCAP::CloudController::PollableJobModel.find(guid: job_guid)
          expect(background_job).to be_complete, "Failed due to: #{background_job.cf_api_error}"

          web_process.reload
          expect(web_process.instances).to eq(4)
          expect(web_process.memory).to eq(2048)
          expect(web_process.disk_quota).to eq(256)
          expect(web_process.command).to eq('new-command')
          expect(web_process.health_check_type).to eq('http')
          expect(web_process.health_check_http_endpoint).to eq('/test')
          expect(web_process.health_check_timeout).to eq(10)

          process2 = VCAP::CloudController::ProcessModel.find(app_guid: app_model.guid, type: 'worker')
          expect(process2.instances).to eq(2)
          expect(process2.memory).to eq(512)
          expect(process2.disk_quota).to eq(1024)
          expect(process2.command).to eq('bar')
          expect(process2.health_check_type).to eq('port')
          expect(process2.health_check_timeout).to eq(150)
        end
      end
    end

    describe 'multiple buildpacks' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make }
      let(:buildpack2) { VCAP::CloudController::Buildpack.make }
      let(:yml_manifest) do
        {
          'applications' => [
            {
              'name' => 'blah',
              'buildpacks' => [buildpack.name, buildpack2.name]
            }
          ]
        }.to_yaml
      end

      it 'applies the manifest' do
        post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

        expect(last_response.status).to eq(202)
        job_guid = VCAP::CloudController::PollableJobModel.last.guid
        expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job_guid}))

        Delayed::Worker.new.work_off
        background_job = VCAP::CloudController::PollableJobModel.find(guid: job_guid)
        expect(background_job).to be_complete, "Failed due to: #{background_job.cf_api_error}"

        app_model.reload
        lifecycle_data = app_model.lifecycle_data
        expect(lifecycle_data.buildpacks).to eq([buildpack.name, buildpack2.name])
      end
    end
  end

  describe 'GET /v3/apps/:guid/manifest' do
    let(:app_model) { FactoryBot.create(:app, lifecycle_type, space: space, environment_variables: { 'one' => 'tomato', 'two' => 'potato' }) }

    let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(app: app_model, service_instance: service_instance) }
    let!(:service_binding2) { VCAP::CloudController::ServiceBinding.make(app: app_model, service_instance: service_instance2) }
    let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'si-1') }
    let!(:service_instance2) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'si-2') }

    let!(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: route) }
    let!(:route_mapping2) { VCAP::CloudController::RouteMappingModel.make(app: app_model, route: second_route) }

    let!(:worker_process) do
      VCAP::CloudController::ProcessModelFactory.make(
        app: app_model,
        type: 'worker',
        command: 'Do a thing',
        health_check_type: 'http',
        health_check_http_endpoint: '/foobar',
        health_check_timeout: 5,
      )
    end

    context 'for a buildpack' do
      let(:lifecycle_type) { 'buildpack' }
      let!(:buildpack) { VCAP::CloudController::Buildpack.make }
      let!(:buildpack2) { VCAP::CloudController::Buildpack.make }

      let(:expected_yml_manifest) do
        {
          'applications' => [
            {
              'name' => app_model.name,
              'env' => {
                'one' => 'tomato',
                'two' => 'potato'
              },
              'buildpacks' => [buildpack.name, buildpack2.name],
              'stack' => buildpack.stack,
              'services' => [service_binding.service_instance_name, service_binding2.service_instance_name],
              'routes' => [
                { 'route' => "#{route.host}.#{route.domain.name}" },
                { 'route' => "#{second_route.host}.#{second_route.domain.name}/path" }
              ],
              'processes' => [
                {
                  'type' => process.type,
                  'instances' => process.instances,
                  'memory' => "#{process.memory}M",
                  'disk_quota' => "#{process.disk_quota}M",
                  'health-check-type' => process.health_check_type,
                },
                {
                  'type' => worker_process.type,
                  'instances' => worker_process.instances,
                  'memory' => "#{worker_process.memory}M",
                  'disk_quota' => "#{worker_process.disk_quota}M",
                  'command' => worker_process.command,
                  'health-check-type' => worker_process.health_check_type,
                  'health-check-http-endpoint' => worker_process.health_check_http_endpoint,
                  'timeout' => worker_process.health_check_timeout,
                },
              ]
            }
          ]
        }.to_yaml
      end

      before do
        app_model.lifecycle_data.update(
          buildpacks: [buildpack.name, buildpack2.name],
          stack: buildpack.stack
        )
      end

      it 'retrieves an app manifest for the app' do
        get "/v3/apps/#{app_model.guid}/manifest", nil, user_header

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(expected_yml_manifest)
      end
    end

    context 'for a docker app' do
      let(:lifecycle_type) { 'docker' }
      let(:docker_package) do
        VCAP::CloudController::PackageModel.make(
          :docker,
          app: app_model,
          docker_username: 'xXxMyL1ttlePwnyxXx')
      end

      let(:droplet) do
        VCAP::CloudController::DropletModel.make app: app_model, package: docker_package
      end

      let(:app_model) do
        FactoryBot.create(:app, :docker, space: space, environment_variables: { 'one' => 'tomato', 'two' => 'potato' })
      end

      before do
        app_model.update(droplet: droplet)
      end

      let(:expected_yml_manifest) do
        {
          'applications' => [
            {
              'name' => app_model.name,
              'env' => {
                'one' => 'tomato',
                'two' => 'potato'
              },
              'docker' => {
                'image' => docker_package.image,
                'username' => 'xXxMyL1ttlePwnyxXx'
              },
              'services' => [service_binding.service_instance_name, service_binding2.service_instance_name],
              'routes' => [
                { 'route' => "#{route.host}.#{route.domain.name}" },
                { 'route' => "#{second_route.host}.#{second_route.domain.name}/path" }
              ],
              'processes' => [
                {
                  'type' => process.type,
                  'instances' => process.instances,
                  'memory' => "#{process.memory}M",
                  'disk_quota' => "#{process.disk_quota}M",
                  'health-check-type' => process.health_check_type,
                },
                {
                  'type' => worker_process.type,
                  'instances' => worker_process.instances,
                  'memory' => "#{worker_process.memory}M",
                  'disk_quota' => "#{worker_process.disk_quota}M",
                  'command' => worker_process.command,
                  'health-check-type' => worker_process.health_check_type,
                  'health-check-http-endpoint' => worker_process.health_check_http_endpoint,
                  'timeout' => worker_process.health_check_timeout,
                },
              ]
            }
          ]
        }.to_yaml
      end

      it 'retrieves an app manifest for the app' do
        get "/v3/apps/#{app_model.guid}/manifest", nil, user_header

        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(expected_yml_manifest)
      end
    end
  end
end
