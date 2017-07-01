require 'rails_helper'

RSpec.describe BuildsController, type: :controller do
  describe '#create' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let(:package) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        state: VCAP::CloudController::PackageModel::READY_STATE,
        type: VCAP::CloudController::PackageModel::BITS_TYPE,
      )
    end
    let(:stagers) { instance_double(VCAP::CloudController::Stagers) }
    let(:stager) { double(:stager, stage: nil) }
    let(:req_body) do
      {
        package: {
          guid: package.guid
        },
      }
    end

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_app).and_return(stager)
      app_model.lifecycle_data.update(buildpacks: nil, stack: VCAP::CloudController::Stack.default.name)
      set_current_user_as_admin
    end

    it 'returns a 201 Created response' do
      post :create, body: req_body
      expect(response.status).to eq(201), response.body
    end

    it 'creates a new build for the package' do
      expect { post :create, body: req_body }.
        to change { VCAP::CloudController::BuildModel.count }.from(0).to(1)
      build = VCAP::CloudController::BuildModel.last
      expect(build.package.guid).to eq(package.guid)
    end

    context 'if staging is in progress on any package on the app' do
      before do
        allow_any_instance_of(VCAP::CloudController::AppModel).to receive(:staging_in_progress?).and_return true
      end

      it 'returns a 422 Unprocessable Entity and an informative error message' do
        post :create, body: req_body
        expect(response.status).to eq 422
        expect(response.body).to include 'Only one build can be STAGING at a time per application.'
      end
    end

    context 'when the request is not valid' do
      let(:bad_request) { { package: {} } }

      it 'returns a 422 Unprocessable Entity' do
        post :create, body: bad_request

        expect(response.status).to eq 422
        expect(response.body).to include('UnprocessableEntity')
      end

      context 'when the package does not exist' do
        let(:req_body) do
          {
            package: {
              guid: 'notexist-package'
            },
          }
        end

        it 'returns a 422 Unprocessable Entity' do
          post :create, body: req_body

          expect(response.status).to eq(422)
          expect(response.body).to include('UnprocessableEntity')
          expect(response.body).to include('Unable to use package. Ensure that the package exists and you have access to it.')
        end
      end
    end

    context 'when a BuildError is raised' do
      before do
        allow_any_instance_of(VCAP::CloudController::BuildCreate).
          to receive(:create_and_stage).and_raise(VCAP::CloudController::BuildCreate::BuildError.new('an error occurred'))
      end

      it 'returns a 422 Unprocessable Entity' do
        post :create, body: req_body

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('an error occurred')
      end
    end

    describe 'buildpack lifecycle' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make }
      let(:buildpack_request) { 'http://dan-and-zach-awesome-pack.com' }
      let(:buildpack_lifecycle) do
        {
          type: 'buildpack',
          data: {
            buildpacks: [buildpack_request],
            stack: 'cflinuxfs2'
          },
        }
      end
      let(:req_body) do
        {
          package: {
            guid: package.guid
          },
          lifecycle: buildpack_lifecycle
        }
      end
      context 'when there is a buildpack request' do
        context 'when a git url is requested' do
          it 'works with a valid url' do
            post :create, body: req_body

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::BuildModel.last.lifecycle_data.buildpacks).to eq(['http://dan-and-zach-awesome-pack.com'])
          end

          context 'when the url is invalid' do
            let(:buildpack_request) { 'totally-broke!' }

            it 'returns a 422' do
              post :create, body: req_body

              expect(response.status).to eq(422)
              expect(response.body).to include('UnprocessableEntity')
            end
          end
        end

        context 'when the buildpack is not a url' do
          let(:buildpack_request) { buildpack.name }

          it 'uses buildpack by name' do
            post :create, body: req_body

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::BuildModel.last.buildpack_lifecycle_data.buildpacks).to eq([buildpack.name])
          end

          context 'when the buildpack does not exist' do
            let(:buildpack_request) { 'notfound' }

            it 'returns a 422' do
              post :create, body: req_body

              expect(response.status).to eq(422)
              expect(response.body).to include('UnprocessableEntity')
            end
          end
        end

        context 'when an empty array of buildpacks is specified' do
          let(:buildpack_lifecycle) do
            {
              type: 'buildpack',
              data: {
                buildpacks: [],
                stack: 'cflinuxfs2'
              },
            }
          end

          it 'does NOT set a buildpack on the droplet lifecycle data' do
            post :create, body: req_body

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::BuildModel.last.lifecycle_data.buildpacks).to be_empty
          end
        end

        context 'when buildpacks is null' do
          let(:buildpack_lifecycle) do
            {
              type: 'buildpack',
              data: {
                buildpacks: nil,
                stack: 'cflinuxfs2'
              },
            }
          end

          it 'does NOT set a buildpack on the droplet lifecycle data' do
            post :create, body: req_body

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::BuildModel.last.lifecycle_data.buildpacks).to be_empty
          end
        end
      end

      context 'when there is no buildpack request' do
        let(:req_body_without_lifecycle) do
          {
            package: {
              guid: package.guid
            }
          }
        end
        context 'when app has a buildpack' do
          before do
            app_model.lifecycle_data.update(buildpacks: [buildpack.name])
          end

          it 'uses the apps buildpack' do
            post :create, body: req_body_without_lifecycle

            expect(response.status).to eq(201)
            expect(VCAP::CloudController::BuildModel.last.lifecycle_data.buildpacks).to eq(app_model.lifecycle_data.buildpacks)
          end
        end
      end
    end

    describe 'docker lifecycle' do
      let(:docker_app_model) { VCAP::CloudController::AppModel.make(:docker, space: space) }
      let(:package) do
        VCAP::CloudController::PackageModel.make(:docker,
          app_guid: docker_app_model.guid,
          type: VCAP::CloudController::PackageModel::DOCKER_TYPE,
          state: VCAP::CloudController::PackageModel::READY_STATE
        )
      end
      let(:docker_lifecycle) do
        { type: 'docker', data: {} }
      end
      let(:req_body) do
        {
          package: {
            guid: package.guid
          },
          lifecycle: docker_lifecycle
        }
      end

      before do
        expect(docker_app_model.lifecycle_type).to eq('docker')
      end

      context 'when diego_docker is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
        end

        it 'returns a 201 Created response and creates a build model with an associated package' do
          expect { post :create, body: req_body }.
            to change { VCAP::CloudController::BuildModel.count }.from(0).to(1)
          build = VCAP::CloudController::BuildModel.last
          expect(build.package.guid).to eq(package.guid)

          expect(response.status).to eq 201
        end

        context 'when the user adds additional body parameters' do
          let(:docker_lifecycle) do
            { type: 'docker', data: 'foobar' }
          end

          it 'raises a 422' do
            post :create, body: req_body

            expect(response.status).to eq(422)
            expect(response.body).to include('UnprocessableEntity')
          end
        end
      end

      context 'when diego_docker feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: nil)
        end

        it 'raises 403' do
          post :create, body: req_body

          expect(response.status).to eq(403)
          expect(response.body).to include('FeatureDisabled')
          expect(response.body).to include('diego_docker')
        end
      end
    end

    describe 'staging_details' do
      let(:memory_in_mb) { TestConfig.config[:staging][:minimum_staging_memory_mb] + 1 }
      let(:disk_in_mb) { TestConfig.config[:staging][:minimum_staging_disk_mb] + 1 }
      let(:environment_variables) do
        { envVarName: 'envVarValue' }
      end

      let(:req_body) do
        {
          package: {
            guid: package.guid
          },
          staging_memory_in_mb: memory_in_mb,
          staging_disk_in_mb: disk_in_mb,
          environment_variables: environment_variables,
        }
      end

      before do
        TestConfig.override(
          {
            staging: {
              minimum_staging_memory_mb: 5,
              minimum_staging_disk_mb: 5,
            },
            maximum_app_disk_in_mb: 10,
          }
        )
      end

      context 'staging_memory_in_mb' do
        it 'sets the staging_memory_in_mb in staging_details' do
          post :create, body: req_body
          expect(response.status).to eq(201), response.body
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.staging_memory_in_mb).to eq(memory_in_mb)
            expect(staging_details.staging_disk_in_mb).to eq(disk_in_mb)
            expect(staging_details.environment_variables['envVarName']).to eq('envVarValue')
          end
        end
      end
    end

    describe 'handling droplet create errors' do
      let(:build_create) { instance_double(VCAP::CloudController::BuildCreate) }

      before do
        allow(VCAP::CloudController::BuildCreate).to receive(:new).and_return(build_create)
      end

      context 'when the request package is invalid' do
        before do
          allow(build_create).to receive(:create_and_stage).and_raise(VCAP::CloudController::BuildCreate::InvalidPackage)
        end

        it 'returns a 400 InvalidRequest error' do
          post :create, body: req_body

          expect(response.status).to eq(400)
          expect(response.body).to include('InvalidRequest')
        end
      end

      context 'when the space quota is exceeded' do
        before do
          allow(build_create).to receive(:create_and_stage).and_raise(
            VCAP::CloudController::BuildCreate::SpaceQuotaExceeded.new('helpful message')
          )
        end

        it 'returns 422 Unprocessable' do
          post :create, body: req_body

          expect(response.status).to eq(422)
          expect(response.body).to include("space's memory limit exceeded")
          expect(response.body).to include('helpful message')
        end
      end

      context 'when the org quota is exceeded' do
        before do
          allow(build_create).to receive(:create_and_stage).and_raise(
            VCAP::CloudController::BuildCreate::OrgQuotaExceeded.new('helpful message')
          )
        end

        it 'returns 422 Unprocessable' do
          post :create, body: req_body

          expect(response.status).to eq(422)
          expect(response.body).to include("organization's memory limit exceeded")
          expect(response.body).to include('helpful message')
        end
      end

      context 'when the disk limit is exceeded' do
        before do
          allow(build_create).to receive(:create_and_stage).and_raise(VCAP::CloudController::BuildCreate::DiskLimitExceeded)
        end

        it 'returns 422 Unprocessable' do
          post :create, body: req_body

          expect(response.status).to eq(422)
          expect(response.body).to include('disk limit exceeded')
        end
      end
    end

    describe 'permissions' do
      context 'when the user is an admin' do
        before do
          set_current_user_as_admin
        end

        it 'returns a 201 Created response' do
          post :create, body: req_body
          expect(response.status).to eq 201
        end
      end

      context 'when the user is a space developer' do
        before do
          set_current_user(make_developer_for_space(space))
        end

        it 'returns 201' do
          post :create, body: req_body
          expect(response.status).to eq 201
        end
      end

      context 'when the user is a read only admin' do
        before do
          set_current_user(VCAP::CloudController::User.make, admin_read_only: true)
        end

        it 'returns 403' do
          post :create, body: req_body
          expect(response.status).to eq 403
        end
      end

      context 'when the user is a global auditor' do
        before do
          set_current_user_as_global_auditor
        end

        it 'returns 403' do
          post :create, body: req_body
          expect(response.status).to eq 403
        end
      end

      context 'when the user is a space manager' do
        before do
          set_current_user(make_manager_for_space(space))
        end

        it 'returns 403' do
          post :create, body: req_body
          expect(response.status).to eq 403
        end
      end

      context 'when the user is a space auditor' do
        before do
          set_current_user(make_auditor_for_space(space))
        end

        it 'returns 403' do
          post :create, body: req_body
          expect(response.status).to eq 403
        end
      end

      context 'when the user is a org manager' do
        before do
          set_current_user(make_manager_for_org(org))
        end

        it 'returns 403' do
          post :create, body: req_body
          expect(response.status).to eq 403
        end
      end

      context 'when the user is a org auditor' do
        before do
          set_current_user(make_auditor_for_org(org))
        end

        it 'returns 404' do
          post :create, body: req_body
          expect(response.status).to eq 404
        end
      end

      context 'when the user is a org billing manager' do
        before do
          set_current_user(make_billing_manager_for_org(org))
        end

        it 'returns 404' do
          post :create, body: req_body
          expect(response.status).to eq 404
        end
      end
    end
  end

  describe '#show' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:organization) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: organization) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }
    let(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let(:build) { VCAP::CloudController::BuildModel.make(package: package) }
    let!(:droplet) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        package_guid: package.guid,
        build: build,
      )
    end

    context 'with sufficient permissions' do
      before do
        allow_user_read_access_for(user, spaces: [space])
        allow_user_secret_access(user, space: space)
      end

      it 'returns a 200 OK and the build' do
        get :show, guid: build.guid

        expect(response.status).to eq(200)
        expect(parsed_body['guid']).to eq(build.guid)
      end

      context 'when the build does not exist' do
        it 'returns a 404 Not Found' do
          get :show, guid: 'shablam!'

          expect(response.status).to eq(404)
          expect(response.body).to include('ResourceNotFound')
        end
      end
    end

    context 'permissions' do
      {
        'space_developer' => 200,
        'org_manager' => 200,
        'space_manager' => 200,
        'space_auditor' => 200,
        'admin' => 200,
        'admin_read_only' => 200,
        'org_billing_manager' => 404,
        'org_auditor' => 404,
        'org_user' => 404,
      }.each do |role, expected_return_value|
        context "as an #{role}" do
          before do
            set_current_user_as_role(
              role: role,
              org: organization,
              space: space,
              user: user,
              scopes: %w(cloud_controller.read)
            )
          end

          it "returns #{expected_return_value}" do
            get :show, guid: build.guid
            expect(response.status).to eq(expected_return_value), "Expected #{expected_return_value}, got: #{response.status} with body: #{response.body}"
          end
        end
      end

      context 'when the user does not have the read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'returns a 403 NotAuthorized error' do
          get :show, guid: build.guid

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end
    end
  end
end
