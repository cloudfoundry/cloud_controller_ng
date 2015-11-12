require 'rails_helper'

describe AppsPackagesController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  describe '#create_new' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }
    let(:req_body) { { type: 'bits' } }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    context 'bits' do
      it 'returns a 201 and the package' do
        expect(app_model.packages.count).to eq(0)

        post :create, guid: app_model.guid, body: req_body

        expect(response.status).to eq 201
        expect(app_model.reload.packages.count).to eq(1)
        created_package = app_model.packages.first

        response_guid = JSON.parse(response.body)['guid']
        expect(response_guid).to eq created_package.guid
      end

      context 'admin' do
        before do
          @request.env.merge!(admin_headers)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 201 and the response' do
          expect(app_model.packages.count).to eq(0)

          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 201
          expect(app_model.reload.packages.count).to eq(1)
          created_package = app_model.packages.first

          response_guid = JSON.parse(response.body)['guid']
          expect(response_guid).to eq created_package.guid
        end
      end

      context 'with an invalid type field' do
        let(:req_body) { { type: 'ninja' } }

        it 'returns an UnprocessableEntity error' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include "must be one of 'bits, docker'"
        end
      end

      context 'when the app does not exist' do
        it 'returns a 404 ResourceNotFound error' do
          post :create, guid: 'bogus', body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have write scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'returns a 403 NotAuthorized error' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user cannot create the package' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
        end

        it 'returns a 403 NotAuthorized error' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(VCAP::CloudController::PackageCreate).to receive(:create).and_raise(VCAP::CloudController::PackageCreate::InvalidPackage.new('err'))
        end

        it 'returns 422' do
          post :create, guid: app_model.guid, body: req_body

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
        end
      end
    end

    context 'docker' do
      let(:req_body) do
        {
          type: 'docker',
          data: {
            image:       'registry/image:latest',
            credentials: {
              user:         'user name',
              password:     's3cr3t',
              email:        'email@example.com',
              login_server: 'https://index.docker.io/v1/'
            },
            store_image: true
          }
        }
      end

      it 'returns a 201' do
        expect(app_model.packages.count).to eq(0)
        post :create, guid: app_model.guid, body: req_body

        expect(response.status).to eq 201

        app_model.reload
        package = app_model.packages.first
        expect(package.type).to eq('docker')
        expect(package.docker_data.image).to eq('registry/image:latest')
        expect(package.docker_data.store_image).to eq(true)
      end
    end
  end

  describe '#create_copy' do
    let(:source_app_model) { VCAP::CloudController::AppModel.make }
    let(:original_package) { VCAP::CloudController::PackageModel.make(type: 'bits', app_guid: source_app_model.guid) }
    let(:target_app_model) { VCAP::CloudController::AppModel.make }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns a 201 and the response' do
      expect(target_app_model.packages.count).to eq(0)

      post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

      copied_package = target_app_model.reload.packages.first
      response_guid  = JSON.parse(response.body)['guid']

      expect(response.status).to eq 201
      expect(copied_package.type).to eq(original_package.type)
      expect(response_guid).to eq copied_package.guid
    end

    context 'permissions' do
      context 'when the user does not have write scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
        end

        it 'returns a 403 NotAuthorized error' do
          post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the source package' do
        before do
          allow(membership).to receive(:has_any_roles?).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER],
            source_app_model.space.guid, source_app_model.space.organization.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user cannot modify the source target_app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER],
            source_app_model.space.guid, source_app_model.space.organization.guid).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER], source_app_model.space.guid).and_return(false)
        end

        it 'returns a 403 NotAuthorized error' do
          post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the target app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], target_app_model.space.guid, target_app_model.space.organization.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user cannot create the package' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], target_app_model.space.guid, target_app_model.space.organization.guid).and_return(true)
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER], target_app_model.space.guid).and_return(false)
        end

        it 'returns a 403 NotAuthorized error' do
          post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'admin' do
        before do
          @request.env.merge!(admin_headers)
          allow(membership).to receive(:has_any_roles?).and_return(false)
        end

        it 'returns a 201 and the response' do
          expect(target_app_model.packages.count).to eq(0)

          post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

          copied_package = target_app_model.reload.packages.first
          response_guid  = JSON.parse(response.body)['guid']

          expect(response.status).to eq 201
          expect(copied_package.type).to eq(original_package.type)
          expect(response_guid).to eq copied_package.guid
        end
      end
    end

    context 'when the source package does not exist' do
      it 'returns a 404 ResourceNotFound error' do
        post :create, guid: target_app_model.guid, source_package_guid: 'bogus package guid'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the target target_app does not exist' do
      it 'returns a 404 ResourceNotFound error' do
        post :create, guid: 'bogus', source_package_guid: original_package.guid

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the source target_app and the target target_app are the same' do
      let(:original_package) { VCAP::CloudController::PackageModel.make(type: 'bits', app_guid: target_app_model.guid) }

      it 'returns 422' do
        post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
      end
    end

    context 'when the package is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::PackageCopy).to receive(:copy).and_raise(VCAP::CloudController::PackageCopy::InvalidPackage.new('ruh roh'))
      end

      it 'returns 422' do
        post :create, guid: target_app_model.guid, source_package_guid: original_package.guid

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'ruh roh'
      end
    end
  end

  describe '#index' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let(:org) { space.organization }

    before do
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    it 'returns a 200 and presents the response' do
      app_model_package_1 = app_model.add_package(VCAP::CloudController::PackageModel.make)
      app_model_package_2 = app_model.add_package(VCAP::CloudController::PackageModel.make)
      VCAP::CloudController::PackageModel.make
      VCAP::CloudController::PackageModel.make

      get :index, guid: app_model.guid

      response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
      expect(response.status).to eq 200
      expect(response_guids).to match_array([app_model_package_1, app_model_package_2].map(&:guid))
    end

    context 'permissions' do
      context 'admin' do
        let!(:app_model_package_1) { app_model.add_package(VCAP::CloudController::PackageModel.make) }
        let!(:app_model_package_2) { app_model.add_package(VCAP::CloudController::PackageModel.make) }

        before do
          @request.env.merge!(admin_headers)
          allow(membership).to receive(:has_any_roles?).and_return(false)

          VCAP::CloudController::PackageModel.make
          VCAP::CloudController::PackageModel.make
        end

        it 'returns a 200 and presents the response' do
          get :index, guid: app_model.guid

          response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
          expect(response.status).to eq 200
          expect(response_guids).to match_array([app_model_package_1, app_model_package_2].map(&:guid))
        end
      end

      context 'when the user does not have read scope' do
        before do
          @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])))
        end

        it 'raises an ApiError with a 403 code' do
          get :index, guid: app_model.guid

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user cannot read the app' do
        before do
          allow(membership).to receive(:has_any_roles?).with(
            [VCAP::CloudController::Membership::SPACE_DEVELOPER,
             VCAP::CloudController::Membership::SPACE_MANAGER,
             VCAP::CloudController::Membership::SPACE_AUDITOR,
             VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :index, guid: app_model.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end

    context 'when the app does not exist' do
      it 'raises an ApiError with a 404 code' do
        get :index, guid: 'fake guid'

        expect(response.status).to eq 404
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the request parameters are invalid' do
      context 'because there are unknown parameters' do
        it 'returns an 400 Bad Request' do
          get :index, guid: app_model.guid, invalid: 'thing', bad: 'stuff'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Unknown query parameter(s): 'invalid', 'bad'")
        end
      end

      context 'because there are invalid values in parameters' do
        it 'returns an 400 Bad Request' do
          get :index, guid: app_model.guid, per_page: 50000

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include 'Per page must be between'
        end
      end
    end
  end
end
