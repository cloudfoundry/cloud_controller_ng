require 'rails_helper'

RSpec.describe IsolationSegmentsController, type: :controller do
  let(:user) { set_current_user(VCAP::CloudController::User.make) }
  let(:space) { VCAP::CloudController::Space.make }

  describe '#create' do
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

  describe '#show' do
    let!(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'some-name') }

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      context 'when the isolation segment has been created' do
        it 'returns a 200 and the correct isolation segment' do
          get :show, guid: isolation_segment.guid

          expect(response.status).to eq 200
          expect(parsed_body['guid']).to eq(isolation_segment.guid)
          expect(parsed_body['name']).to eq(isolation_segment.name)
          expect(parsed_body['links']['self']['href']).to eq("/v3/isolation_segments/#{isolation_segment.guid}")
        end
      end

      context 'when the isolation segment has not been created' do
        it 'returns a 404' do
          get :show, guid: 'noexistent-guid'

          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        get :show, guid: isolation_segment.guid
        expect(response.status).to eq 403
      end
    end
  end

  describe '#index' do
    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      context 'when isolation segments have been created' do
        let!(:isolation_segment1) { VCAP::CloudController::IsolationSegmentModel.make(name: 'segment1') }
        let!(:isolation_segment2) { VCAP::CloudController::IsolationSegmentModel.make(name: 'segment2') }

        it 'returns a 200 and a list of the existing isolation segments' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids.length).to eq(2)
          expect(response_guids).to include(isolation_segment1.guid)
          expect(response_guids).to include(isolation_segment2.guid)
        end
      end

      context 'when no isolation segments have been created' do
        it 'returns a 200 and an empty list' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids.length).to eq(0)
        end
      end

      context 'when using query params' do
        context 'with invalid param format' do
          it 'returns a 400' do
            get :index, order_by: '^=%'

            expect(response.status).to eq 400
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
          end
        end

        context 'with a parameter value outside the allowed values' do
          it 'returns a 400 and a list of allowed values' do
            get :index, order_by: 'name'

            expect(response.status).to eq 400
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
          end
        end

        context 'with an unknown query param' do
          it 'returns 400 and a list of the unknown params' do
            get :index, meow: 'woof', kaplow: 'zoom'

            expect(response.status).to eq 400
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include("Unknown query parameter(s): 'meow', 'kaplow'")
          end
        end

        context 'with invalid pagination params' do
          it 'returns 400 and the allowed param range' do
            get :index, per_page: 99999999999999999

            expect(response.status).to eq 400
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include 'Per page must be between'
          end
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        get :index
        expect(response.status).to eq 403
      end
    end
  end
end
