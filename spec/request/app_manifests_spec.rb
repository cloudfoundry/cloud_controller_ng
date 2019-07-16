require 'spec_helper'

RSpec.describe 'App Manifests' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make }
  let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
  let(:route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space, host: 'a_host') }
  let(:second_route) {
    VCAP::CloudController::Route.make(domain: shared_domain, space: space, path: '/path', host: 'b_host')
  }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }

  let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/apps/:guid/actions/apply_manifest' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client, bind: {}) }
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
      VCAP::CloudController::LabelsUpdate.update(app_model, { 'potato' => 'french',
        'downton' => 'abbey road', }, VCAP::CloudController::AppLabelModel)
      VCAP::CloudController::AnnotationsUpdate.update(app_model, { 'potato' => 'baked',
        'berry' => 'white', }, VCAP::CloudController::AppAnnotationModel)
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
      expect(app_model.labels.map { |label| { key: label.key_name, value: label.value } }).
        to match_array([{ key: 'potato', value: 'yam' }, { key: 'songs', value: 'missing' }])
      expect(app_model.annotations.map { |a| { key: a.key, value: a.value } }).
        to match_array([{ key: 'potato', value: 'idaho' }, { key: 'juice', value: 'newton' }])
    end

    context 'sidecars' do
      let(:yml_manifest) do
        {
          'applications' => [
            {
              'name' => 'blah',
              'sidecars' => sidecars_attributes
            }
          ]
        }.to_yaml
      end

      let(:sidecars_attributes) do
        [
          {
            'process_types' => ['worker'],
            'command'       => 'bundle exec sidecar_for_web_only',
            'name'          => 'my-sidecar',
            'memory'        => 300,
          }
        ]
      end

      it 'creates new sidecars' do
        expect {
          post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
          Delayed::Worker.new.work_off
        }.to change { VCAP::CloudController::SidecarModel.count }.from(0).to(1)

        expect(last_response.status).to eq(202)
        sidecar = VCAP::CloudController::SidecarModel.last
        expect(sidecar.name).to          eq('my-sidecar')
        expect(sidecar.command).to       eq('bundle exec sidecar_for_web_only')
        expect(sidecar.process_types).to eq(['worker'])
        expect(sidecar.memory).to eq(300)
      end

      context 'when a sidecar already exists' do
        let!(:sidecar) { VCAP::CloudController::SidecarModel.make(name: 'my-sidecar', app: app_model, command: 'rackup', memory: 200) }
        let!(:sidecar_process_type) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar, type: 'web', app_guid: app_model.guid) }

        it 'updates based on name' do
          expect {
            post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
            Delayed::Worker.new.work_off
          }.not_to change { VCAP::CloudController::SidecarModel.count }

          expect(last_response.status).to eq(202)
          sidecar.reload
          expect(sidecar.name).to          eq('my-sidecar')
          expect(sidecar.command).to       eq('bundle exec sidecar_for_web_only')
          expect(sidecar.process_types).to eq(['worker'])
          expect(sidecar.memory).to eq(300)
        end

        context 'when sidecar name is not provided' do
          let(:sidecars_attributes) do
            [
              {
                'process_types' => ['worker'],
                'command'       => 'bundle exec sidecar_for_web_only',
              }
            ]
          end

          it 'returns 422' do
            post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
            expect(last_response.status).to eq(422)
          end
        end
      end
    end

    describe 'scaling proceses when there are existing sidecars' do
      let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model, type: 'web', memory: 400) }
      let!(:sidecar) { VCAP::CloudController::SidecarModel.make(name: 'my-sidecar', app: app_model, command: 'rackup', memory: 200) }
      let!(:sidecar_process_type) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar, type: 'web', app_guid: app_model.guid) }

      context 'when the new process memory is more than the cumulative sidecars memory' do
        let(:yml_manifest) do
          {
            'applications' => [
              { 'name' => app_model.name,
                'processes' => [{
                  'type' => 'web',
                  'memory' => '300MB'
                }]
              }
            ]
          }.to_yaml
        end
        it 'returns a 200' do
          post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
          Delayed::Worker.new.work_off
          expect(process.reload.memory).to eq 300
          expect(last_response.status).to eq(202)
        end
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

    context 'service bindings' do
      let(:yml_manifest) do
        {
          'applications' => [
            {
              'name' => 'blah',
              'services' =>
                [
                  {
                    'name' => service_instance.name,
                    'parameters' => {
                      'foo' => 'bar'
                    }
                  }
                ]
            }
          ]
        }.to_yaml
      end

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:bind).and_return({ async: false, binding: {}, operation: nil })
      end

      it 'creates the service bindings with the parameters' do
        expect {
          post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
          Delayed::Worker.new.work_off
        }.to change { VCAP::CloudController::ServiceBinding.count }.from(0).to(1)

        expect(last_response.status).to eq(202)

        service_binding = VCAP::CloudController::ServiceBinding.last
        expect(client).
          to have_received(:bind).with(an_instance_of(VCAP::CloudController::ServiceBinding), arbitrary_parameters: { foo: 'bar' }, accepts_incomplete: anything)
        expect(service_binding.service_instance_name).to eq(service_instance.name)
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
                'no_route' => true,
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

    describe 'no_route' do
      let(:yml_manifest) do
        {
          'applications' => [
            { 'name' => 'blah',
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

        post "/v3/apps/#{app_model.guid}/actions/apply_manifest?no_route=true", yml_manifest, yml_headers(user_header)

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

    context 'when a deployment is in progress' do
      before do
        TestConfig.override(temporary_disable_deployments: false)
        deployment = VCAP::CloudController::DeploymentModelTestFactory.make(
          state: VCAP::CloudController::DeploymentModel::DEPLOYING_STATE,
          app: app_model,
        )
        expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
        post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)
        expect(last_response.status).to eq(202)
      end

      context 'when the manifest attempts to update/scale non-web processes' do
        let(:yml_manifest) do
          { 'applications' =>
            [{ 'name' => 'blah',
              'processes' => [{ 'type' => 'worker', 'instances' => '3', 'command' => 'echo hi' }]
            }]
          }.to_yaml
        end

        it 'succeeds' do
          Delayed::Worker.new.work_off
          job = VCAP::CloudController::PollableJobModel.last

          expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{job.guid}))
          expect(job.state).to eq('COMPLETE')
        end
      end
    end
  end

  describe 'GET /v3/apps/:guid/manifest' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space, environment_variables: { 'one' => 'tomato', 'two' => 'potato' }) }

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

    let!(:app_label) { VCAP::CloudController::AppLabelModel.make(resource_guid: app_model.guid, key_name: 'potato', value: 'idaho') }
    let!(:app_annotation) { VCAP::CloudController::AppAnnotationModel.make(resource_guid: app_model.guid, key: 'style', value: 'mashed') }

    let!(:sidecar1) { VCAP::CloudController::SidecarModel.make(name: 'authenticator', command: './authenticator', app: app_model) }
    let!(:sidecar2) { VCAP::CloudController:: SidecarModel.make(name: 'my_sidecar', command: 'rackup', app: app_model) }

    let!(:sidecar_process_type1) { VCAP::CloudController::SidecarProcessTypeModel.make(type: 'worker', sidecar: sidecar1, app_guid: app_model.guid) }
    let!(:sidecar_process_type2) { VCAP::CloudController::SidecarProcessTypeModel.make(type: 'web', sidecar: sidecar1, app_guid: app_model.guid) }
    let!(:sidecar_process_type3) { VCAP::CloudController::SidecarProcessTypeModel.make(type: 'other_worker', sidecar: sidecar2, app_guid: app_model.guid) }

    context 'for a buildpack' do
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
              'metadata' => { 'labels' => { 'potato' => 'idaho' }, 'annotations' => { 'style' => 'mashed' } },
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
              ],
              'sidecars' => [
                {
                  'name'          => 'authenticator',
                  'process_types' => ['web', 'worker'],
                  'command'       => './authenticator',
                },
                {
                  'name'          => 'my_sidecar',
                  'process_types' => ['other_worker'],
                  'command'       => 'rackup',
                }
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
        VCAP::CloudController::AppModel.make(:docker, space: space, environment_variables: { 'one' => 'tomato', 'two' => 'potato' })
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
              'metadata' => { 'labels' => { 'potato' => 'idaho' }, 'annotations' => { 'style' => 'mashed' } },
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
              ],
              'sidecars' => [
                {
                  'name'          => 'authenticator',
                  'process_types' => ['web', 'worker'],
                  'command'       => './authenticator',
                },
                {
                  'name'          => 'my_sidecar',
                  'process_types' => ['other_worker'],
                  'command'       => 'rackup',
                }
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
