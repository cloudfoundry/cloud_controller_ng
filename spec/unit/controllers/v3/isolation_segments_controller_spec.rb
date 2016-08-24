require 'rails_helper'

RSpec.describe IsolationSegmentsController, type: :controller do
  describe '#create' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:req_body) do
      {
        name: 'some-name',
      }
    end

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      it 'returns a 201 Created  and the isolation segment' do
        post :create, body: req_body

        expect(response.status).to eq 201

        isolation_segment_model = VCAP::CloudController::IsolationSegmentModel.last
        expect(isolation_segment_model.name).to eq 'some-name'
      end

      context 'when the request is malformed' do
        let(:req_body) {
          {
            bork: 'some-name',
          }
        }
        it 'returns a 422' do
          post :create, body: req_body
          expect(response.status).to eq 422
        end
      end

      context 'when the requested name is a duplicate' do
        it 'returns a 422' do
          VCAP::CloudController::IsolationSegmentModel.make(name: 'some-name')
          post :create, body: req_body

          expect(response.status).to eq 422
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        post :create, body: req_body
        expect(response.status).to eq 403
      end
    end
  end
end
