require 'rails_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe V3::JobsController, type: :controller do
  describe '#show' do
    let!(:job) { VCAP::CloudController::PollableJobModel.make(resource_type: 'app') }
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user, scopes: ['cloud_controller.read'])
    end

    context 'permissions' do
      context 'when the user does not have cc.read' do
        it 'returns a 403 unauthorized error' do
          set_current_user(user, scopes: ['cloud_controller.write'])

          get :show, params: { guid: job.guid }
          expect(response).to have_http_status(:forbidden)
          expect(response).to have_error_message('You are not authorized to perform the requested action')
        end
      end

      context 'when the user has cc.read' do
        it 'allows the user to access the job' do
          get :show, params: { guid: job.guid }
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when the user is an admin' do
        it 'allows the user to access the job' do
          set_current_user(user, scopes: ['cloud_controller.admin'])
          get :show, params: { guid: job.guid }
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when the requested job exists' do
      it 'returns the job details' do
        get :show, params: { guid: job.guid }
        expect(parsed_body['operation']).to eq job.operation
        expect(parsed_body['state']).to eq job.state
      end
    end

    context 'when the requested job does not exist' do
      it 'returns a 404' do
        get :show, params: { guid: 'fake-guid' }
        expect(response).to have_http_status :not_found
      end
    end
  end
end
