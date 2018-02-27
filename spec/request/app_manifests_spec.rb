require 'spec_helper'

RSpec.describe 'App Manifests' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
  let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/apps/:guid/actions/apply_manifest' do
    let(:yml_manifest) do
      {
        'applications' => [
          { 'name' => 'blah',
            'instances' => 4,
            'memory' => '2048MB',
            'disk_quota' => '1.5GB'
          }
        ]
      }.to_yaml
    end

    it 'applies the manifest' do
      web_process = app_model.web_process
      expect(web_process.instances).to eq(1)

      post "/v3/apps/#{app_model.guid}/actions/apply_manifest", yml_manifest, yml_headers(user_header)

      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{VCAP::CloudController::PollableJobModel.last.guid}))

      Delayed::Worker.new.work_off

      web_process.reload
      expect(web_process.instances).to eq(4)
      expect(web_process.memory).to eq(2048)
      expect(web_process.disk_quota).to eq(1536)
    end
  end
end
