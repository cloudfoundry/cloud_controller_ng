require 'rails_helper'

describe DropletsController, type: :controller do
  let(:membership) { instance_double(VCAP::CloudController::Membership) }

  describe '#create' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:stagers) { instance_double(VCAP::CloudController::Stagers) }
    let(:package) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid,
                                               type: VCAP::CloudController::PackageModel::BITS_TYPE,
                                               state: VCAP::CloudController::PackageModel::READY_STATE)
    end

    before do
      @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make)))
      allow(VCAP::CloudController::Membership).to receive(:new).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_package).and_return(double(:stager, stage: nil))
      VCAP::CloudController::BuildpackLifecycleDataModel.make(
        app: app_model,
        buildpack: nil,
        stack: VCAP::CloudController::Stack.default.name
      )
    end

    it 'returns a 201 Created response' do
      post :create, package_guid: package.guid
      expect(response.status).to eq 201
    end

    it 'creates a new droplet for the package' do
      expect {
        post :create, package_guid: package.guid
      }.to change { VCAP::CloudController::DropletModel.count }.from(0).to(1)

      expect(VCAP::CloudController::DropletModel.last.package.guid).to eq(package.guid)
    end

    context 'if staging is in progress on any package on the app' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppModel).to receive(:staging_in_progress?).and_return true
      end

      it 'returns a 422 Unprocessable Entity and an informative error message' do
        post :create, package_guid: package.guid
        expect(response.status).to eq 422
        expect(response.body).to include 'Only one package can be staged at a time per application.'
      end
    end

    context 'admin' do
      before do
        @request.env.merge!(json_headers(admin_headers))
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 201 Created response and creates a droplet' do
        expect {
          post :create, package_guid: package.guid
        }.to change { VCAP::CloudController::DropletModel.count }.from(0).to(1)
        expect(response.status).to eq 201
      end
    end

    context 'when the package does not exist' do
      it 'returns a 404 ResourceNotFound error' do
        post :create, package_guid: 'made-up-guid'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'when the user does not have the write scope' do
      before do
        @request.env.merge!(json_headers(headers_for(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])))
      end

      it 'raises an ApiError with a 403 code' do
        post :create, package_guid: package.guid

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
        post :create, package_guid: package.guid

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
        post :create, package_guid: package.guid

        expect(response.status).to eq(403)
        expect(response.body).to include('NotAuthorized')
      end
    end

    describe 'buildpack lifecycle' do
      describe 'buildpack request' do
        let(:req_body) { { lifecycle: { type: 'buildpack', data: { buildpack: buildpack_request } } } }
        let(:buildpack) { VCAP::CloudController::Buildpack.make }

        context 'when a git url is requested' do
          let(:buildpack_request) { 'http://dan-and-zach-awesome-pack.com' }

          it 'works with a valid url' do
            post :create, { package_guid: package.guid, body: req_body }

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::DropletModel.last.lifecycle_data.buildpack).to eq('http://dan-and-zach-awesome-pack.com')
          end

          context 'when the url is invalid' do
            let(:buildpack_request) { 'totally-broke!' }

            it 'returns a 422' do
              post :create, { package_guid: package.guid, body: req_body }

              expect(response.status).to eq(422)
              expect(response.body).to include('UnprocessableEntity')
            end
          end
        end

        context 'when the buildpack is not a url' do
          let(:buildpack_request) { buildpack.name }

          it 'uses buildpack by name' do
            post :create, { package_guid: package.guid, body: req_body }

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::DropletModel.last.buildpack_lifecycle_data.buildpack).to eq(buildpack.name)
          end

          context 'when the buildpack does not exist' do
            let(:buildpack_request) { 'notfound' }

            it 'returns a 422' do
              post :create, { package_guid: package.guid, body: req_body }

              expect(response.status).to eq(422)
              expect(response.body).to include('UnprocessableEntity')
            end
          end
        end

        context 'when buildpack is not requested and app has a buildpack' do
          let(:req_body) { {} }

          before do
            app_model.buildpack_lifecycle_data.buildpack = buildpack.name
            app_model.buildpack_lifecycle_data.save
          end

          it 'uses the apps buildpack' do
            post :create, { package_guid: package.guid, body: req_body }

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::DropletModel.last.lifecycle_data.buildpack).to eq(app_model.lifecycle_data.buildpack)
          end
        end
      end
    end

    describe 'docker lifecycle' do
      let(:docker_app_model) { VCAP::CloudController::AppModel.make(:docker) }
      let(:req_body) { { lifecycle: { type: 'docker', data: {} } } }
      let!(:package) do
        VCAP::CloudController::PackageModel.make(:docker,
          app_guid: docker_app_model.guid,
          type: VCAP::CloudController::PackageModel::DOCKER_TYPE,
          state: VCAP::CloudController::PackageModel::READY_STATE
        )
      end

      before do
        expect(docker_app_model.lifecycle_type).to eq('docker')
        VCAP::CloudController::BuildpackLifecycleDataModel.make(
          app: docker_app_model,
          buildpack: nil,
          stack: VCAP::CloudController::Stack.default.name
        )
      end

      context 'when diego_docker is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
        end

        it 'returns a 201 Created response' do
          expect {
            post :create, package_guid: package.guid, body: req_body
          }.to change { VCAP::CloudController::DropletModel.count }.from(0).to(1)
          expect(response.status).to eq 201
        end

        context 'when the user adds additional body parameters' do
          let(:req_body) do
            {
              lifecycle:
                {
                  type: 'docker',
                  data:
                        {
                          foobar: 'iamverysmart'
                        }
                }
            }
          end

          it 'raises a 422' do
            post :create, package_guid: package.guid, body: req_body

            expect(response.status).to eq(422)
            expect(response.body).to include('UnprocessableEntity')
          end
        end
      end

      context 'when diego_docker is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: nil)
        end

        context 'non-admin user' do
          it 'raises 403' do
            post :create, package_guid: package.guid, body: req_body

            expect(response.status).to eq(403)
            expect(response.body).to include('FeatureDisabled')
            expect(response.body).to include('diego_docker')
          end
        end

        context 'admin user' do
          before do
            @request.env.merge!(json_headers(admin_headers))
            allow(membership).to receive(:has_any_roles?).and_return(false)
          end

          it 'returns a 201 Created response and creates a droplet' do
            expect {
              post :create, package_guid: package.guid, body: req_body
            }.to change { VCAP::CloudController::DropletModel.count }.from(0).to(1)
            expect(response.status).to eq 201
          end
        end
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
          post :create, package_guid: package.guid, body: req_body

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
          post :create, package_guid: package.guid, body: req_body

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.environment_variables).to include('key_from_package' => 'should_merge')
          expect(VCAP::CloudController::DropletModel.last.environment_variables).to include('key_from_app' => 'should_merge')
        end

        it 'clobbers the existing value from the app' do
          post :create, package_guid: package.guid, body: req_body

          expect(response.status).to eq(201)
          expect(VCAP::CloudController::DropletModel.last.environment_variables).to include('conflicting_key' => 'value_from_package')
        end
      end

      context 'when the environment variables are not valid' do
        let(:req_body) { { 'environment_variables' => 'invalid_param' } }

        it 'returns a 422' do
          post :create, package_guid: package.guid, body: req_body

          expect(response.status).to eq(422)
          expect(response.body).to include('UnprocessableEntity')
        end
      end
    end

    context 'when the request body is not valid' do
      let(:req_body) { { 'memory_limit' => 'invalid' } }

      it 'returns an UnprocessableEntity error' do
        post :create, package_guid: package.guid, body: req_body

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    describe 'handling action errors' do
      let(:droplet_create) { instance_double(VCAP::CloudController::DropletCreate) }

      before do
        allow(VCAP::CloudController::DropletCreate).to receive(:new).and_return(droplet_create)
      end

      context 'when the request package is invalid' do
        before do
          allow(droplet_create).to receive(:create_and_stage).and_raise(VCAP::CloudController::DropletCreate::InvalidPackage)
        end

        it 'returns a 400 InvalidRequest error' do
          post :create, package_guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('InvalidRequest')
        end
      end

      context 'when the space quota is exceeded' do
        before do
          allow(droplet_create).to receive(:create_and_stage).and_raise(VCAP::CloudController::DropletCreate::SpaceQuotaExceeded)
        end

        it 'returns 400 UnableToPerform' do
          post :create, package_guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('UnableToPerform')
          expect(response.body).to include('Staging request')
          expect(response.body).to include("space's memory limit exceeded")
        end
      end

      context 'when the org quota is exceeded' do
        before do
          allow(droplet_create).to receive(:create_and_stage).and_raise(VCAP::CloudController::DropletCreate::OrgQuotaExceeded)
        end

        it 'returns 400 UnableToPerform' do
          post :create, package_guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('UnableToPerform')
          expect(response.body).to include('Staging request')
          expect(response.body).to include("organization's memory limit exceeded")
        end
      end

      context 'when the disk limit is exceeded' do
        before do
          allow(droplet_create).to receive(:create_and_stage).and_raise(VCAP::CloudController::DropletCreate::DiskLimitExceeded)
        end

        it 'returns 400 UnableToPerform' do
          post :create, package_guid: package.guid

          expect(response.status).to eq(400)
          expect(response.body).to include('UnableToPerform')
          expect(response.body).to include('Staging request')
          expect(response.body).to include('disk limit exceeded')
        end
      end
    end
  end

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
      expect(parsed_body['guid']).to eq(droplet.guid)
    end

    context 'admin' do
      before do
        @request.env.merge!(admin_headers)
        allow(membership).to receive(:has_any_roles?).and_return(false)
      end

      it 'returns a 200 OK and the droplet' do
        get :show, guid: droplet.guid

        expect(response.status).to eq(200)
        expect(parsed_body['guid']).to eq(droplet.guid)
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

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([user_droplet_1, user_droplet_2].map(&:guid))
    end

    it 'returns pagination links for /v3/droplets' do
      get :index
      expect(parsed_body['pagination']['first']['href']).to start_with('/v3/droplets')
    end

    context 'accessed as an app subresource' do
      it 'returns droplets for the app' do
        app       = VCAP::CloudController::AppModel.make(space: space)
        droplet_1 = VCAP::CloudController::DropletModel.make(app_guid: app.guid)
        droplet_2 = VCAP::CloudController::DropletModel.make(app_guid: app.guid)
        VCAP::CloudController::DropletModel.make

        get :index, app_guid: app.guid

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([droplet_1, droplet_2].map(&:guid))
      end

      it 'provides the correct base url in the pagination links' do
        get :index, app_guid: app.guid

        expect(parsed_body['pagination']['first']['href']).to include("/v3/apps/#{app.guid}/droplets")
      end

      context 'when the user cannot read the app' do
        before do
          space.remove_developer(user)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, app_guid: app.guid

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end

      context 'when the app does not exist' do
        it 'returns a 404 Resource Not Found error' do
          get :index, app_guid: 'made-up'

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user is an admin' do
      before do
        @request.env.merge!(admin_headers)
      end

      it 'returns all droplets' do
        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
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
