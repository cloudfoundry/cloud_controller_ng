require 'rails_helper'

describe AppsDropletsController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }
  let(:app_model) { VCAP::CloudController::AppModel.make }
  let(:app_guid) { app_model.guid }
  let(:space) { app_model.space }
  let(:space_guid) { space.guid }
  let(:org) { space.organization }
  let(:org_guid) { org.guid }

  describe '#index' do
    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns droplets the user has roles to see' do
      droplet_1 = VCAP::CloudController::DropletModel.make(app_guid: app_guid)
      droplet_2 = VCAP::CloudController::DropletModel.make(app_guid: app_guid)
      VCAP::CloudController::DropletModel.make

      get :index, guid: app_model.guid

      response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
      expect(response.status).to eq(200)
      expect(response_guids).to match_array([droplet_1, droplet_2].map(&:guid))
    end

    context 'query params' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, guid: app_model.guid, order_by: 'meow'

          expect(response.status).to eq 400
          expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, guid: app_model.guid, meow: 'bad-val', nyan: 'mow'

          expect(response.status).to eq 400
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('nyan')
          expect(response.body).to include('meow')
        end
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
      end

      context 'the app exists' do
        it 'returns a 200 and all droplets belonging to the app' do
          droplet_1 = VCAP::CloudController::DropletModel.make(app_guid: app_guid)
          droplet_2 = VCAP::CloudController::DropletModel.make(app_guid: app_guid)
          VCAP::CloudController::DropletModel.make

          get :index, guid: app_model.guid

          response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids).to match_array([droplet_1, droplet_2].map(&:guid))
        end
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, guid: 'hello-i-do-not-exist'

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end

    context 'permissions' do
      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space_guid, org_guid).and_return(false)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, guid: app_model.guid

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user does not have read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'raises an ApiError with a 403 code' do
        get :index, guid: app_model.guid

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end
  end
end
