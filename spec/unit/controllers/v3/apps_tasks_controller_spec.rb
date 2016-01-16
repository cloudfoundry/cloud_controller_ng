require 'rails_helper'

describe AppsTasksController, type: :controller do
  describe '#create' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(app_guid: app_model.guid,
                                               state: VCAP::CloudController::DropletModel::STAGED_STATE)
    end
    let(:req_body) do
      {
        "name": 'mytask',
        "command": 'rake db:migrate && true',
      }
    end

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      app_model.droplet = droplet
      app_model.save
    end

    it 'returns a 202 and the task' do
      post :create, guid: app_model.guid, body: req_body

      expect(response.status).to eq 202
      expect(JSON.parse(response.body)).to include('name' => 'mytask')
    end

    it 'creates a task for the app' do
      expect(app_model.tasks.count).to eq(0)

      post :create, guid: app_model.guid, body: req_body

      expect(app_model.reload.tasks.count).to eq(1)
      expect(app_model.tasks.first).to eq(VCAP::CloudController::TaskModel.last)
    end

    context 'invalid task' do
      it 'returns a useful error message' do
        post :create, guid: app_model.guid, body: {}

        expect(response.status).to eq 422
      end
    end
  end
end
