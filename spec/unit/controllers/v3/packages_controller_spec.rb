require 'rails_helper'

describe PackagesController, type: :controller do
  let(:package_presenter) { instance_double(VCAP::CloudController::PackagePresenter) }
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  describe '#upload' do
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:space) { package.space }
    let(:org) { space.organization }
    let(:params) { { 'bits_path' => 'path/to/bits' } }
    let(:expected_response) { 'response stuff' }
    let(:form_headers) { { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' } }

    before do
      @request.env.merge!(form_headers)
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(VCAP::CloudController::PackagePresenter).to receive(:new).and_return(package_presenter)
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(package_presenter).to receive(:present_json).and_return(expected_response)
    end

    it 'returns 200 and updates the package state' do
      post :upload, params.merge(guid: package.guid)

      expect(response.status).to eq(200)
      expect(response.body).to eq(expected_response)
      expect(package_presenter).to have_received(:present_json).with(an_instance_of(VCAP::CloudController::PackageModel))
      expect(package.reload.state).to eq(VCAP::CloudController::PackageModel::PENDING_STATE)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 200 and updates the package state' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(200)
        expect(response.body).to eq(expected_response)
        expect(package_presenter).to have_received(:present_json).with(an_instance_of(VCAP::CloudController::PackageModel))
        expect(package.reload.state).to eq(VCAP::CloudController::PackageModel::PENDING_STATE)
      end
    end

    context 'when app_bits_upload is disabled' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'app_bits_upload', enabled: false, error_message: nil)
      end

      context 'non-admin user' do
        it 'raises 403' do
          post :upload, params.merge(guid: package.guid)

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('app_bits_upload')
        end
      end

      context 'admin user' do
        before { @request.env.merge!(admin_headers) }

        it 'returns 200 and updates the package state' do
          post :upload, params.merge(guid: package.guid)

          expect(response.status).to eq(200)
          expect(response.body).to eq(expected_response)
          expect(package_presenter).to have_received(:present_json).with(an_instance_of(VCAP::CloudController::PackageModel))
          expect(package.reload.state).to eq(VCAP::CloudController::PackageModel::PENDING_STATE)
        end
      end
    end

    context 'when the package type is not bits' do
      before do
        package.type = 'docker'
        package.save
      end

      it 'returns a 422 Unprocessable' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('Package type must be bits.')
      end
    end

    context 'when the package does not exist' do
      it 'returns a 404 ResourceNotFound error' do
        post :upload, params.merge(guid: 'not-real')

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the message is not valid' do
      let(:params) { {} }

      it 'returns a 422 UnprocessableEntity error' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'returns an Unauthorized error' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the user cannot read the package' do
      before do
        allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns a 404' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user does not have correct roles to upload' do
      before do
        allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(true)
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid).and_return(false)
      end

      it 'returns a 403' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')

        expect(membership).to have_received(:has_any_roles?).with([VCAP::CloudController::Membership::SPACE_DEVELOPER], space.guid)
      end
    end

    context 'when the bits have already been uploaded' do
      before do
        package.state = VCAP::CloudController::PackageModel::READY_STATE
        package.save
      end

      it 'returns a 400 PackageBitsAlreadyUploaded error' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(400)
        expect(response.body).to include('PackageBitsAlreadyUploaded')
      end
    end

    context 'when the package is invalid' do
      before do
        allow_any_instance_of(VCAP::CloudController::PackageUpload).to receive(:upload).and_raise(VCAP::CloudController::PackageUpload::InvalidPackage.new('err'))
      end

      it 'returns 422' do
        post :upload, params.merge(guid: package.guid)

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end
  end

  describe '#download' do
    let(:package) { VCAP::CloudController::PackageModel.make(state: 'READY') }
    let(:space) { package.space }
    let(:org) { space.organization }

    before do
      blob = instance_double(CloudController::Blobstore::FogBlob, public_download_url: 'http://package.example.com')
      allow_any_instance_of(CloudController::Blobstore::Client).to receive(:blob).and_return(blob)
      allow_any_instance_of(CloudController::Blobstore::Client).to receive(:local?).and_return(false)

      allow(VCAP::CloudController::PackagePresenter).to receive(:new).and_return(package_presenter)
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make)))
    end

    it 'returns 302 and the redirect' do
      get :download, guid: package.guid

      expect(response.status).to eq(302)
      expect(response.headers['Location']).to eq('http://package.example.com')
    end

    context 'when the package is not of type bits' do
      before do
        package.type = 'docker'
        package.save
      end

      it 'returns 422' do
        get :download, guid: package.guid

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'when the package has no bits' do
      before do
        package.state = VCAP::CloudController::PackageModel::CREATED_STATE
        package.save
      end

      it 'returns 422' do
        get :download, guid: package.guid

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    context 'when the package cannot be found' do
      it 'returns 404' do
        get :download, { guid: 'a-bogus-guid' }

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'user does not have read scope' do
      before do
        @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])))
      end

      it 'returns an Unauthorized error' do
        get :download, guid: package.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'user does not have package read permissions' do
      before do
        allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
        allow(membership).to receive(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
      end

      it 'returns 404' do
        get :download, guid: package.guid

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'user is an admin' do
      let(:download_location) { 'http://package.download.url' }

      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns 302' do
        get :download, guid: package.guid

        expect(response.status).to eq(302)
        expect(response.headers['Location']).to eq('http://package.example.com')
      end
    end
  end

  describe '#show' do
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:expected_response) { 'im a response' }

    before do
      allow(VCAP::CloudController::PackagePresenter).to receive(:new).and_return(package_presenter)
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
      allow(package_presenter).to receive(:present_json).and_return(expected_response)
    end

    it 'returns a 200 OK and the package' do
      get :show, guid: package.guid

      expect(response.status).to eq(200)
      expect(response.body).to eq(expected_response)
      expect(package_presenter).to have_received(:present_json).with(package)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 200 OK and the package' do
        get :show, guid: package.guid

        expect(response.status).to eq(200)
        expect(response.body).to eq(expected_response)
        expect(package_presenter).to have_received(:present_json).with(package)
      end
    end

    context 'when the user does not have the read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'returns a 403 NotAuthorized error' do
        get :show, guid: package.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the package does not exist' do
      it 'returns a 404 Not Found' do
        get :show, guid: 'made-up-guid'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user has incorrect roles' do
      let(:space) { package.space }
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
        get :show, guid: package.guid

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')

        expect(membership).to have_received(:has_any_roles?).with(
          [VCAP::CloudController::Membership::SPACE_DEVELOPER,
           VCAP::CloudController::Membership::SPACE_MANAGER,
           VCAP::CloudController::Membership::SPACE_AUDITOR,
           VCAP::CloudController::Membership::ORG_MANAGER], space.guid, org.guid)
      end
    end
  end

  describe '#destroy' do
    let(:package) { VCAP::CloudController::PackageModel.make }

    before do
      allow(VCAP::CloudController::PackagePresenter).to receive(:new).and_return(package_presenter)
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      @request.env.merge!(headers_for(VCAP::CloudController::User.make))
    end

    it 'returns a 204 NO CONTENT and deletes the package' do
      delete :destroy, guid: package.guid

      expect(response.status).to eq 204
      expect(response.body).to be_empty
      expect(package.exists?).to be_falsey
    end

    context 'when the package does not exist' do
      it 'returns a 404 Not Found' do
        delete :destroy, guid: 'nono'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user does not have write scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read']))
      end

      it 'returns an Unauthorized error' do
        delete :destroy, guid: package.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the user cannot read the package' do
      let(:space) { package.space }
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
        delete :destroy, guid: package.guid

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user can read but cannot write to the package' do
      let(:space) { package.space }
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

      it 'raises ApiError NotAuthorized' do
        delete :destroy, guid: package.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 204 NO CONTENT' do
        delete :destroy, guid: package.guid

        expect(response.status).to eq(204)
        expect(response.body).to be_empty
      end
    end
  end

  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:space) { app_model.space }
    let!(:user_package_1) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:user_package_2) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:admin_package) { VCAP::CloudController::PackageModel.make }

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

    it 'lists the packages visible to the user' do
      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([user_package_1, user_package_2].map(&:guid))
    end

    it 'returns pagination links for /v3/packages' do
      get :index
      expect(parsed_body['pagination']['first']['href']).to start_with('/v3/packages')
    end

    context 'when accessed as an app subresource' do
      it 'uses the app as a filter' do
        app = VCAP::CloudController::AppModel.make(space: space)
        package_1 = VCAP::CloudController::PackageModel.make(app_guid: app.guid)
        package_2 = VCAP::CloudController::PackageModel.make(app_guid: app.guid)
        VCAP::CloudController::PackageModel.make

        get :index, app_guid: app.guid

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([package_1.guid, package_2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, app_guid: app_model.guid
        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app_model.guid}/packages")
      end

      context 'the app does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, app_guid: 'hello-i-do-not-exist'

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the app' do
        before do
          space.remove_developer(user)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, app_guid: app_model.guid

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'lists all the packages' do
        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([user_package_1, user_package_2, admin_package].map(&:guid))
      end
    end

    context 'when pagination options are specified' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        get :index, params

        parsed_response = parsed_body
        response_guids = parsed_response['resources'].map { |r| r['guid'] }
        expect(parsed_response['pagination']['total_results']).to eq(2)
        expect(response_guids.length).to eq(per_page)
      end
    end

    context 'when the user does not have the read scope' do
      before do
        @request.env.merge!(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.write']))
      end

      it 'returns a 403 NotAuthorized error' do
        get :index

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when parameters are invalid' do
      context 'because there are unknown parameters' do
        let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

        it 'returns an 400 Bad Request' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include("Unknown query parameter(s): 'invalid', 'bad'")
        end
      end

      context 'because there are invalid values in parameters' do
        let(:params) { { 'per_page' => 9999999999 } }

        it 'returns an 400 Bad Request' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Per page must be between')
        end
      end
    end
  end

  describe '#create' do
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

          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq 201
          expect(app_model.reload.packages.count).to eq(1)
          created_package = app_model.packages.first

          response_guid = parsed_body['guid']
          expect(response_guid).to eq created_package.guid
        end

        context 'admin' do
          before do
            @request.env.merge!(admin_headers)
            allow(membership).to receive(:has_any_roles?).and_return(false)
          end

          it 'returns a 201 and the response' do
            expect(app_model.packages.count).to eq(0)

            post :create, app_guid: app_model.guid, body: req_body

            expect(response.status).to eq 201
            expect(app_model.reload.packages.count).to eq(1)
            created_package = app_model.packages.first

            response_guid = parsed_body['guid']
            expect(response_guid).to eq created_package.guid
          end
        end

        context 'with an invalid type field' do
          let(:req_body) { { type: 'ninja' } }

          it 'returns an UnprocessableEntity error' do
            post :create, app_guid: app_model.guid, body: req_body

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include "must be one of 'bits, docker'"
          end
        end

        context 'when the app does not exist' do
          it 'returns a 404 ResourceNotFound error' do
            post :create, app_guid: 'bogus', body: req_body

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
          end
        end

        context 'when the user does not have write scope' do
          before do
            @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
          end

          it 'returns a 403 NotAuthorized error' do
            post :create, app_guid: app_model.guid, body: req_body

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
            post :create, app_guid: app_model.guid, body: req_body

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
            post :create, app_guid: app_model.guid, body: req_body

            expect(response.status).to eq 403
            expect(response.body).to include 'NotAuthorized'
          end
        end

        context 'when the package is invalid' do
          before do
            allow_any_instance_of(VCAP::CloudController::PackageCreate).to receive(:create).and_raise(VCAP::CloudController::PackageCreate::InvalidPackage.new('err'))
          end

          it 'returns 422' do
            post :create, app_guid: app_model.guid, body: req_body

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
              image: 'registry/image:latest'
            }
          }
        end

        it 'returns a 201' do
          expect(app_model.packages.count).to eq(0)
          post :create, app_guid: app_model.guid, body: req_body

          expect(response.status).to eq 201

          app_model.reload
          package = app_model.packages.first
          expect(package.type).to eq('docker')
          expect(package.docker_data.image).to eq('registry/image:latest')
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

        post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

        copied_package = target_app_model.reload.packages.first
        response_guid  = parsed_body['guid']

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
            post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

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
            post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

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
            post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

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
            post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

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
            post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

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

            post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

            copied_package = target_app_model.reload.packages.first
            response_guid  = parsed_body['guid']

            expect(response.status).to eq 201
            expect(copied_package.type).to eq(original_package.type)
            expect(response_guid).to eq copied_package.guid
          end
        end
      end

      context 'when the source package does not exist' do
        it 'returns a 404 ResourceNotFound error' do
          post :create, app_guid: target_app_model.guid, source_package_guid: 'bogus package guid'

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the target target_app does not exist' do
        it 'returns a 404 ResourceNotFound error' do
          post :create, app_guid: 'bogus', source_package_guid: original_package.guid

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(VCAP::CloudController::PackageCopy).to receive(:copy).and_raise(VCAP::CloudController::PackageCopy::InvalidPackage.new('ruh roh'))
        end

        it 'returns 422' do
          post :create, app_guid: target_app_model.guid, source_package_guid: original_package.guid

          expect(response.status).to eq 422
          expect(response.body).to include 'UnprocessableEntity'
          expect(response.body).to include 'ruh roh'
        end
      end
    end
  end
end
