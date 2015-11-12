require 'rails_helper'

describe DropletsController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  describe '#show' do
    let(:droplet) { VCAP::CloudController::DropletModel.make }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns a 200 OK and the droplet' do
      get :show, guid: droplet.guid

      expect(response.status).to eq(200)
      expect(MultiJson.load(response.body)['guid']).to eq(droplet.guid)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 200 OK and the droplet' do
        get :show, guid: droplet.guid

        expect(response.status).to eq(200)
        expect(MultiJson.load(response.body)['guid']).to eq(droplet.guid)
      end
    end

    context 'when the droplet does not exist' do
      it 'returns a 404 Not Found' do
        get :show, guid: 'shablam!'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user does not have the read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'returns a 403 NotAuthorized error' do
        get :show, guid: droplet.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the user has incorrect roles' do
      let(:space) { droplet.space }
      let(:org) { space.organization }

      before do
        allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
        allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 not found' do
        get :show, guid: droplet.guid

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end
  end

  describe '#destroy' do
    let(:droplet) { VCAP::CloudController::DropletModel.make }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns a 204 NO CONTENT' do
      delete :destroy, guid: droplet.guid

      expect(response.status).to eq(204)
      expect(response.body).to be_empty
      expect(droplet.exists?).to be_falsey
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 204 NO CONTENT' do
        delete :destroy, guid: droplet.guid

        expect(response.status).to eq(204)
        expect(response.body).to be_empty
        expect(droplet.exists?).to be_falsey
      end
    end

    context 'when the droplet does not exist' do
      it 'returns a 404 Not Found' do
        delete :destroy, guid: 'not-found'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'returns 403' do
        delete :destroy, guid: droplet.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the user cannot read the droplet due to roles' do
      let(:space) { droplet.space }
      let(:org) { space.organization }

      before do
        allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404 ResourceNotFound error' do
        delete :destroy, guid: droplet.guid

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user can read but cannot write to the droplet' do
      let(:space) { droplet.space }
      let(:org) { space.organization }

      before do
        allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).
          and_return(true)
        allow(membership).to receive(:has_any_roles?).with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).
          and_return(false)
      end

      it 'returns 403 NotAuthorized' do
        delete :destroy, guid: droplet.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end
  end

  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }
    let(:app) { VCAP::CloudController::AppModel.make }
    let(:space) { app.space }
    let!(:user_droplet_1) { VCAP::CloudController::DropletModel.make(app_guid: app.guid) }
    let!(:user_droplet_2) { VCAP::CloudController::DropletModel.make(app_guid: app.guid) }
    let!(:admin_droplet) { VCAP::CloudController::DropletModel.make }

    before do
      @request.env.merge!(headers_for(user))
      space.organization.add_user(user)
      space.organization.save
      space.add_developer(user)
      space.save
    end

    it 'returns 200' do
      get :index
      expect(response.status).to eq(200)
    end

    it 'lists the droplets visible to the user' do
      get :index

      response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([user_droplet_1, user_droplet_2].map(&:guid))
    end

    it 'returns pagination links for /v3/droplets' do
      get :index
      expect(JSON.parse(response.body)['pagination']['first']['href']).to start_with('/v3/droplets')
    end

    context 'when the user is an admin' do
      before do
        @request.env.merge!(admin_headers)
      end

      it 'returns all droplets' do
        get :index

        response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([user_droplet_1, user_droplet_2, admin_droplet].map(&:guid))
      end
    end

    context 'when the user does not have read scope' do
      before do
        @request.env.merge!(headers_for(user, scopes: ['cloud_controller.write']))
      end

      it 'returns a 403 Not Authorized error' do
        get :index

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'query params' do
      context 'invalid param format' do
        let(:params) { { 'order_by' => '^%' } }

        it 'returns 400' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Order by is invalid')
        end
      end

      context 'unknown query param' do
        let(:params) { { 'bad_param' => 'foo' } }

        it 'returns 400' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('bad_param')
        end
      end

      context 'invalid pagination' do
        let(:params) { { 'per_page' => 9999999999999999 } }

        it 'returns 400' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Per page must be between')
        end
      end
    end
  end
end
