require 'rails_helper'

RSpec.describe V3::JobsController, type: :controller do
  describe '#show' do
    let!(:job) { VCAP::CloudController::PollableJobModel.make }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user, scopes: ['cloud_controller.read'])
    end

    context 'permissions' do
      context 'when the user does not have cc.read' do
        it 'returns a 403 unauthorized error' do
          set_current_user(user, scopes: ['cloud_controller.write'])

          get :show, guid: job.guid
          expect(response.status).to eq(403)
          expect(parsed_body['errors'].first['detail']).to eq('You are not authorized to perform the requested action')
        end
      end

      context 'when the user has cc.read' do
        it 'allows the user to access the job' do
          get :show, guid: job.guid
          expect(response.status).to eq(200)
        end
      end

      context 'when the user is an admin' do
        it 'allows the user to access the job' do
          set_current_user(user, scopes: ['cloud_controller.admin'])
          get :show, guid: job.guid
          expect(response.status).to eq(200)
        end
      end
    end

    context 'when the requested job exists' do
      it 'returns the job details' do
        get :show, guid: job.guid
        expect(parsed_body['operation']).to eq job.operation
        expect(parsed_body['state']).to eq job.state
      end
    end

    context 'when the requested job does not exist' do
      it 'returns a 404' do
        get :show, guid: 'fake-guid'
        expect(response.status).to eq 404
      end
    end
  end
end
