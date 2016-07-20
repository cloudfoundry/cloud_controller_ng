require 'rails_helper'

RSpec.describe DropletsController, type: :controller do
  describe '#create' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:stagers) { instance_double(VCAP::CloudController::Stagers) }
    let(:package) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid,
                                               type: VCAP::CloudController::PackageModel::BITS_TYPE,
                                               state: VCAP::CloudController::PackageModel::READY_STATE)
    end
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { app_model.space }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_package).and_return(double(:stager, stage: nil))
      VCAP::CloudController::BuildpackLifecycleDataModel.make(
        app:       app_model,
        buildpack: nil,
        stack:     VCAP::CloudController::Stack.default.name
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

    context 'when the package does not exist' do
      it 'returns a 404 ResourceNotFound error' do
        post :create, package_guid: 'made-up-guid'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
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
      let(:docker_app_model) { VCAP::CloudController::AppModel.make(:docker, space: space) }
      let(:req_body) { { lifecycle: { type: 'docker', data: {} } } }
      let!(:package) do
        VCAP::CloudController::PackageModel.make(:docker,
          app_guid: docker_app_model.guid,
          type:     VCAP::CloudController::PackageModel::DOCKER_TYPE,
          state:    VCAP::CloudController::PackageModel::READY_STATE
        )
      end

      before do
        expect(docker_app_model.lifecycle_type).to eq('docker')
        VCAP::CloudController::BuildpackLifecycleDataModel.make(
          app:       docker_app_model,
          buildpack: nil,
          stack:     VCAP::CloudController::Stack.default.name
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
            set_current_user_as_admin(user: user)
          end

          it 'raises 403' do
            post :create, package_guid: package.guid, body: req_body

            expect(response.status).to eq(403)
            expect(response.body).to include('FeatureDisabled')
            expect(response.body).to include('diego_docker')
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
              'application_name'    => 'name-815'
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
      let(:req_body) { { 'staging_memory_in_mb' => 'invalid' } }

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

    context 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'returns an ApiError with a 403 code' do
          post :create, package_guid: package.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the package due to roles' do
        before do
          disallow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          post :create, package_guid: package.guid

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but cannot write to the package due to roles' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'raises ApiError NotAuthorized' do
          post :create, package_guid: package.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#copy' do
    let(:source_space) { VCAP::CloudController::Space.make }
    let(:target_space) { VCAP::CloudController::Space.make }
    let(:target_app) { VCAP::CloudController::AppModel.make(space_guid: target_space.guid) }
    let(:source_app_guid) { VCAP::CloudController::AppModel.make(space_guid: source_space.guid).guid }
    let(:target_app_guid) { target_app.guid }
    let(:state) { 'STAGED' }
    let!(:source_droplet) { VCAP::CloudController::DropletModel.make(:buildpack, state: state, app_guid: source_app_guid) }
    let(:source_droplet_guid) { source_droplet.guid }
    let(:req_body) do
      {
        relationships: {
          app: { guid: target_app_guid }
        }
      }
    end
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access(user, space: source_space)
      allow_user_read_access(user, space: target_space)
      allow_user_write_access(user, space: target_space)
    end

    it 'returns a 201 OK response with the new droplet' do
      expect {
        post :copy, guid: source_droplet_guid, body: req_body
      }.to change { target_app.reload.droplets.count }.from(0).to(1)

      expect(response.status).to eq(201)
      expect(target_app.droplets.first.guid).to eq(parsed_body['guid'])
    end

    context 'when the request is invalid' do
      it 'returns a 422' do
        post :copy, guid: source_droplet_guid, body: { 'super_duper': 'bad_request' }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
      end
    end

    describe 'permissions' do
      context 'when the user is not a member of the space where the source droplet exists' do
        before do
          disallow_user_read_access(user, space: source_space)
        end

        it 'returns a not found error' do
          post :copy, guid: source_droplet_guid, body: req_body

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user is a member of the space where source droplet exists' do
        before do
          allow_user_read_access(user, space: source_space)
        end

        context 'when the user does not have read access to the target space' do
          before do
            disallow_user_read_access(user, space: target_space)
          end

          it 'returns a 404 ResourceNotFound error' do
            post :copy, guid: source_droplet_guid, body: req_body

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
          end
        end

        context 'when the user has read access, but not write access to the target space' do
          before do
            allow_user_read_access(user, space: target_space)
            disallow_user_write_access(user, space: target_space)
          end

          it 'returns a forbidden error' do
            post :copy, guid: source_droplet_guid, body: req_body

            expect(response.status).to eq(403)
            expect(response.body).to include('NotAuthorized')
          end
        end
      end
    end

    context 'when the source droplet is not STAGED' do
      let(:state) { 'STAGING' }

      it 'returns an invalid request error ' do
        post :copy, guid: source_droplet_guid, body: req_body

        expect(response.status).to eq(400)
        expect(response.body).to include 'UnableToPerform'
        expect(response.body).to include 'source droplet is not staged'
      end
    end

    context 'when the source droplet does not exist' do
      let(:source_droplet_guid) { 'no-source-droplet-here' }
      it 'returns a not found error' do
        post :copy, guid: 'no droplet here', body: req_body

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the target application does not exist' do
      let(:target_app_guid) { 'not a real app guid' }
      it 'returns a not found error' do
        post :copy, guid: 'no droplet here', body: req_body

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
      end
    end
  end

  describe '#show' do
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { droplet.space }

    before do
      allow_user_read_access(user, space: space)
      allow_user_secret_access(user, space: space)
    end

    it 'returns a 200 OK and the droplet' do
      get :show, guid: droplet.guid

      expect(response.status).to eq(200)
      expect(parsed_body['guid']).to eq(droplet.guid)
    end

    context 'when the droplet does not exist' do
      it 'returns a 404 Not Found' do
        get :show, guid: 'shablam!'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user does not have the read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'returns a 403 NotAuthorized error' do
          get :show, guid: droplet.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user can not read from the space' do
        let(:space) { droplet.space }
        let(:org) { space.organization }

        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 not found' do
          get :show, guid: droplet.guid

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end
    end
  end

  describe '#destroy' do
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:space) { droplet.space }

    before do
      allow_user_read_access(user, space: space)
      allow_user_write_access(user, space: space)
    end

    it 'returns a 204 NO CONTENT' do
      delete :destroy, guid: droplet.guid

      expect(response.status).to eq(204)
      expect(response.body).to be_empty
      expect(droplet.exists?).to be_falsey
    end

    context 'when the droplet does not exist' do
      it 'returns a 404 Not Found' do
        delete :destroy, guid: 'not-found'

        expect(response.status).to eq(404)
        expect(response.body).to include('ResourceNotFound')
      end
    end

    context 'permissions' do
      context 'when the user does not have write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'returns 403' do
          delete :destroy, guid: droplet.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user cannot read the droplet due to roles' do
        before do
          disallow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          delete :destroy, guid: droplet.guid

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end

      context 'when the user can read but cannot write to the space' do
        before do
          disallow_user_write_access(user, space: space)
        end

        it 'returns 403 NotAuthorized' do
          delete :destroy, guid: droplet.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:app) { VCAP::CloudController::AppModel.make }
    let!(:space) { app.space }
    let!(:user_droplet_1) { VCAP::CloudController::DropletModel.make(app_guid: app.guid) }
    let!(:user_droplet_2) { VCAP::CloudController::DropletModel.make(app_guid: app.guid) }
    let!(:admin_droplet) { VCAP::CloudController::DropletModel.make }

    before do
      allow_user_read_access(user, space: space)
      stub_readable_space_guids_for(user, space)
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

    context 'when pagination options are specified' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        get :index, params

        parsed_response = parsed_body
        response_guids  = parsed_response['resources'].map { |r| r['guid'] }
        expect(parsed_response['pagination']['total_results']).to eq(2)
        expect(response_guids.length).to eq(per_page)
      end
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
          disallow_user_read_access(user, space: space)
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

    context 'accessed as a package subresource' do
      let(:package) { VCAP::CloudController::PackageModel.make(app_guid: app.guid) }
      let!(:droplet_1) { VCAP::CloudController::DropletModel.make(package_guid: package.guid) }

      it 'returns droplets for the package' do
        get :index, package_guid: package.guid

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([droplet_1].map(&:guid))
      end

      it 'provides the correct base url in the pagination links' do
        get :index, package_guid: package.guid

        expect(parsed_body['pagination']['first']['href']).to include("/v3/packages/#{package.guid}/droplets")
      end

      context 'when the user cannot read the package' do
        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, package_guid: package.guid

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end

      context 'when the package does not exist' do
        it 'returns a 404 Resource Not Found error' do
          get :index, package_guid: 'made-up'

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end
    end

    context 'query params' do
      context 'invalid param format' do
        let(:params) { { 'order_by' => '^%' } }

        it 'returns 400' do
          get :index, params

          expect(response.status).to eq(400)
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
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

    context 'permissions' do
      context 'when the user does not have read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'returns a 403 Not Authorized error' do
          get :index

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user is an admin' do
        before do
          disallow_user_read_access(user, space: space)
          set_current_user_as_admin(user: user)
        end

        it 'returns all droplets' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response_guids).to match_array([user_droplet_1, user_droplet_2, admin_droplet].map(&:guid))
        end
      end

      context 'when the user is a read only admin' do
        before do
          disallow_user_read_access(user, space: space)
          set_current_user_as_admin_read_only(user: user)
        end

        it 'returns all droplets' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response_guids).to match_array([user_droplet_1, user_droplet_2, admin_droplet].map(&:guid))
        end
      end

      context 'when the user has read access, but not write access to the space' do
        before do
          allow_user_read_access(user, space: space)
          disallow_user_write_access(user, space: space)
        end

        it 'returns 200' do
          get :index
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
