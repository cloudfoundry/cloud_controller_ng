require 'spec_helper'

RSpec.describe 'Sidecars' do
  let(:app_model) { VCAP::CloudController::AppModel.make }
  let(:user_header) { headers_for(user) }
  let(:user) { VCAP::CloudController::User.make }

  before do
    app_model.space.organization.add_user(user)
    app_model.space.add_developer(user)
  end

  describe 'POST /v3/apps/:guid/sidecars' do
    let(:sidecar_params) {
      {
          name: 'sidecar_one',
          command: 'bundle exec rackup',
          process_types: ['web', 'other_worker']
      }
    }

    it 'creates a sidecar for an app' do
      expect {
        post "/v3/apps/#{app_model.guid}/sidecars", sidecar_params.to_json, user_header
      }.to change { VCAP::CloudController::SidecarModel.count }.by(1)

      expect(last_response.status).to eq(201), last_response.body
      sidecar = VCAP::CloudController::SidecarModel.last

      expected_response = {
        'guid' => sidecar.guid,
        'name' => 'sidecar_one',
        'command' => 'bundle exec rackup',
        'process_types' => ['other_worker', 'web'],
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => app_model.guid
            }
          }
        }
      }

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    describe 'deleting an app with a sidecar' do
      it 'deletes the sidecar' do
        post "/v3/apps/#{app_model.guid}/sidecars", sidecar_params.to_json, user_header
        delete "/v3/apps/#{app_model.guid}", nil, user_header
        expect(last_response.status).to eq(202)
      end
    end
  end

  describe 'GET /v3/sidecars/:guid' do
    let(:sidecar) { VCAP::CloudController::SidecarModel.make(app: app_model, name: 'sidecar', command: 'smarch') }
    let!(:sidecar_spider) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar, type: 'spider') }
    let!(:sidecar_web) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar, type: 'web') }

    it 'gets the sidecar' do
      get "/v3/sidecars/#{sidecar.guid}", nil, user_header

      expected_response = {
        'guid' => sidecar.guid,
        'name' => 'sidecar',
        'command' => 'smarch',
        'process_types' => ['spider', 'web'],
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => app_model.guid
            }
          }
        }
      }

      expect(last_response.status).to eq(200), last_response.body
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/processes/:guid/sidecars' do
    let!(:sidecar1a) { VCAP::CloudController::SidecarModel.make(app: app_model, name: 'sidecar1a', command: 'missile1a') }
    let!(:sidecar_worker1a) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1a, type: 'worker') }
    let!(:sidecar_web1a) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1a, type: 'web') }

    let!(:sidecar1b) { VCAP::CloudController::SidecarModel.make(app: app_model, name: 'sidecar1b', command: 'missile1b') }
    let!(:sidecar_worker1b) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1b, type: 'worker') }
    let!(:sidecar_web1b) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1b, type: 'web') }

    let!(:sidecar1c) { VCAP::CloudController::SidecarModel.make(app: app_model, name: 'sidecar1c', command: 'missile1c') }
    let!(:sidecar_worker1c) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1c, type: 'worker') }
    let!(:sidecar_web1c) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1c, type: 'web') }

    let!(:sidecar1d) { VCAP::CloudController::SidecarModel.make(app: app_model, name: 'sidecar1d', command: 'missile1d') }
    let!(:sidecar_worker1d) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1d, type: 'fish') }
    let!(:sidecar_web1d) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar1d, type: 'cows') }

    let!(:process1) { VCAP::CloudController::ProcessModel.make(
      :process,
      app:        app_model,
      type:       'web',
      command:    'rackup',
    )
    }

    let!(:app_model2) { VCAP::CloudController::AppModel.make(space: app_model.space, name: 'app2') }
    let!(:sidecar_for_app2) { VCAP::CloudController::SidecarModel.make(app: app_model2, name: 'sidecar2', command: 'missile2') }
    let!(:sidecar_worker2) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar_for_app2, type: 'worker') }
    let!(:sidecar_web2) { VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar_for_app2, type: 'web') }
    let!(:process2) { VCAP::CloudController::ProcessModel.make(
      :process,
      app:        app_model2,
      type:       'web',
      command:    'rackup',
    )
    }

    it "retrieves the process' sidecars" do
      get "/v3/processes/#{process1.guid}/sidecars?per_page=2", nil, user_header

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'total_pages'   => 2,
          'first'         => { 'href' => "#{link_prefix}/v3/processes/#{process1.guid}/sidecars?page=1&per_page=2" },
          'last'          => { 'href' => "#{link_prefix}/v3/processes/#{process1.guid}/sidecars?page=2&per_page=2" },
          'next'          => { 'href' => "#{link_prefix}/v3/processes/#{process1.guid}/sidecars?page=2&per_page=2" },
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid' => sidecar1a.guid,
            'name' => 'sidecar1a',
            'command' => 'missile1a',
            'process_types' => ['web', 'worker'],
            'relationships' => {
              'app' => {
                'data' => {
                  'guid' => app_model.guid,
                },
              },
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
          },
          {
            'guid' => sidecar1b.guid,
            'name' => 'sidecar1b',
            'command' => 'missile1b',
            'process_types' => ['web', 'worker'],
            'relationships' => {
              'app' => {
                'data' => {
                  'guid' => app_model.guid,
                },
              },
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
          },
        ]
      }

      expect(last_response.status).to eq(200), last_response.body
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end
end
