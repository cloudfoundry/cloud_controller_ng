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
    TestConfig.override(kubernetes: {})
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
    let!(:sidecar2) { VCAP::CloudController::SidecarModel.make(name: 'my_sidecar', command: 'rackup', app: app_model) }

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
