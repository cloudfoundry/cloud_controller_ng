require 'spec_helper'

RSpec.describe 'App Manifests' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make }
  let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
  let(:route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space) }
  let(:second_route) { VCAP::CloudController::Route.make(domain: shared_domain, space: space, path: '/path') }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
  let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/apps/:guid/actions/apply_manifest' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
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
          }
        ]
      }.to_yaml
    end

    it 'applies the manifest' do
      web_process = app_model.web_process
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
  end
end
