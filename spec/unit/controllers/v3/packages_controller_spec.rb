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
    let(:file_path) { nil }
    let(:download_location) { nil }
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:space) { package.space }
    let(:org) { space.organization }

    before do
      allow(VCAP::CloudController::PackagePresenter).to receive(:new).and_return(package_presenter)
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make)))
      allow_any_instance_of(VCAP::CloudController::PackageDownload).to receive(:download).and_return([file_path, download_location])
      package.state = 'READY'
      package.save
    end

    context 'when the package exists on NFS' do
      let(:file_path) { '/a/file/path/on/cc' }
      let(:download_location) { nil }

      it 'begins a download' do
        allow(controller).to receive(:send_file)
        allow(controller).to receive(:render).and_return(nil)

        get :download, guid: package.guid

        expect(response.status).to eq(200)
        expect(controller).to have_received(:send_file).with(file_path)
      end
    end

    context 'when the package exists on S3' do
      let(:file_path) { nil }
      let(:download_location) { 'http://package.download.url' }

      it 'returns 302 and the redirect' do
        get :download, guid: package.guid

        expect(response.status).to eq(302)
        expect(response.headers['Location']).to eq(download_location)
      end
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
        expect(response.headers['Location']).to eq(download_location)
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

      response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([user_package_1, user_package_2].map(&:guid))
    end

    it 'returns pagination links for /v3/packages' do
      get :index
      expect(JSON.parse(response.body)['pagination']['first']['href']).to start_with('/v3/packages')
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'lists all the packages' do
        get :index

        response_guids = JSON.parse(response.body)['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([user_package_1, user_package_2, admin_package].map(&:guid))
      end
    end

    context 'when pagination options are specified' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        get :index, params

        parsed_response = JSON.parse(response.body)
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

  describe '#stage' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid,
                                                             type: VCAP::CloudController::PackageModel::BITS_TYPE,
                                                             state: VCAP::CloudController::PackageModel::READY_STATE)
    }
    let(:stagers) { double(:stagers) }

    before do
      @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make)))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_package).and_return(double(:stager, stage: nil))
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
    end

    it 'returns a 201 Created response' do
      post :stage, guid: package.guid
      expect(response.status).to eq 201
    end

    it 'creates a new droplet for the package' do
      expect {
        post :stage, guid: package.guid
      }.to change { VCAP::CloudController::DropletModel.count }.from(0).to(1)

      expect(VCAP::CloudController::DropletModel.last.package.guid).to eq(package.guid)
    end

    context 'admin' do
      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 201 Created response and creates a droplet' do
        expect {
          post :stage, guid: package.guid
        }.to change { VCAP::CloudController::DropletModel.count }.from(0).to(1)
        expect(response.status).to eq 201
      end
    end

    describe 'buildpack request' do
      let(:req_body) { { lifecycle: { type: 'buildpack', data: {  buildpack: buildpack_request } } } }
      let(:buildpack) { VCAP::CloudController::Buildpack.make }

      context 'when a git url is requested' do
        let(:buildpack_request) { 'http://dan-and-zach-awesome-pack.com' }

        it 'works with a valid url' do
          post :stage, { guid: package.guid, body: req_body }

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.lifecycle_data.buildpack).to eq('http://dan-and-zach-awesome-pack.com')
        end

        context 'when the url is invalid' do
          let(:buildpack_request) { 'totally-broke!' }

          it 'returns a 422' do
            post :stage, { guid: package.guid, body: req_body }

            expect(response.status).to eq(422)
            expect(response.body).to include('UnprocessableEntity')
          end
        end
      end

      context 'when the buildpack is not a url' do
        let(:buildpack_request) { buildpack.name }

        it 'uses buildpack by name' do
          post :stage, { guid: package.guid, body: req_body }

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.buildpack_lifecycle_data.buildpack).to eq(buildpack.name)
        end

        context 'when the buildpack does not exist' do
          let(:buildpack_request) { 'notfound' }

          it 'returns a 422' do
            post :stage, { guid: package.guid, body: req_body }

            expect(response.status).to eq(422)
            expect(response.body).to include('UnprocessableEntity')
          end
        end
      end

      context 'when buildpack is not requsted and app has a buildpack' do
        let(:req_body) { {} }

        before do
          VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, buildpack: buildpack.name, stack: VCAP::CloudController::Stack.default.name)
        end

        it 'uses the apps buildpack' do
          post :stage, { guid: package.guid, body: req_body }

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.buildpack_lifecycle_data.buildpack).to eq(app_model.lifecycle_data.buildpack)
        end
      end
    end

    context 'when the package does not exist' do
      it 'returns a 404 ResourceNotFound error' do
        post :stage, guid: 'made-up-guid'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user does not have the write scope' do
      before do
        @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
      end

      it 'raises an ApiError with a 403 code' do
        post :stage, guid: package.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the user cannot read the package due to roles' do
      let(:space) { app_model.space }
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
        post :stage, guid: package.guid

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user can read but cannot write to the package due to roles' do
      let(:space) { app_model.space }
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
        post :stage, guid: package.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    context 'when the stage request includes environment variables' do
      context 'when the environment variables are valid' do
        let(:req_body) do
          {
            'environment_variables' => {
              'application_version' => 'whatuuid',
              'application_name' => 'name-815'
            }
          }
        end

        it 'returns a 201' do
          post :stage, guid: package.guid, body: req_body

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.environment_variables).to include(
              {
                'application_version' => 'whatuuid',
                'application_name'    => 'name-815'
              })
        end
      end

      context 'when user passes in values to the app' do
        let(:req_body) do
          {
            'environment_variables' => {
              'key_from_package' => 'should_merge',
              'conflicting_key'  => 'value_from_package'
            }
          }
        end

        before do
          app_model.environment_variables = { 'key_from_app' => 'should_merge', 'conflicting_key' => 'value_from_app' }
          app_model.save
        end

        it 'merges with the existing environment variables' do
          post :stage, guid: package.guid, body: req_body

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.environment_variables).to include('key_from_package' => 'should_merge')
          expect(VCAP::CloudController::DropletModel.last.environment_variables).to include('key_from_app' => 'should_merge')
        end

        it 'clobbers the existing value from the app' do
          post :stage, guid: package.guid, body: req_body

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.environment_variables).to include('conflicting_key' => 'value_from_package')
        end
      end

      context 'when the environment variables are not valid' do
        let(:req_body) { { 'environment_variables' => 'invalid_param' } }

        it 'returns a 422' do
          post :stage, guid: package.guid, body: req_body

          expect(response.status).to eq(422)
          expect(response.body).to include('UnprocessableEntity')
        end
      end
    end

    context 'when the request body is not valid' do
      let(:req_body) { { 'memory_limit' => 'invalid' } }

      it 'returns an UnprocessableEntity error' do
        post :stage, guid: package.guid, body: req_body

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    describe 'handling action errors' do
      let(:package_stage_action) { double(VCAP::CloudController::PackageStageAction.new) }

      before do
        allow(VCAP::CloudController::PackageStageAction).to receive(:new).and_return(package_stage_action)
      end

      context 'when the request package is invalid' do
        before do
          allow(package_stage_action).to receive(:stage).and_raise(VCAP::CloudController::PackageStageAction::InvalidPackage)
        end

        it 'returns a 400 InvalidRequest error' do
          post :stage, guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('InvalidRequest')
        end
      end

      context 'when the space quota is exceeded' do
        before do
          allow(package_stage_action).to receive(:stage).and_raise(VCAP::CloudController::PackageStageAction::SpaceQuotaExceeded)
        end

        it 'returns 400 UnableToPerform' do
          post :stage, guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('UnableToPerform')
          expect(response.body).to include('Staging request')
          expect(response.body).to include("space's memory limit exceeded")
        end
      end

      context 'when the org quota is exceeded' do
        before do
          allow(package_stage_action).to receive(:stage).and_raise(VCAP::CloudController::PackageStageAction::OrgQuotaExceeded)
        end

        it 'returns 400 UnableToPerform' do
          post :stage, guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('UnableToPerform')
          expect(response.body).to include('Staging request')
          expect(response.body).to include("organization's memory limit exceeded")
        end
      end

      context 'when the disk limit is exceeded' do
        before do
          allow(package_stage_action).to receive(:stage).and_raise(VCAP::CloudController::PackageStageAction::DiskLimitExceeded)
        end

        it 'returns 400 UnableToPerform' do
          post :stage, guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('UnableToPerform')
          expect(response.body).to include('Staging request')
          expect(response.body).to include('disk limit exceeded')
        end
      end
    end
  end
end
