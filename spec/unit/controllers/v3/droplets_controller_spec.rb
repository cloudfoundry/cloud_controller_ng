require 'rails_helper'

RSpec.describe DropletsController, type: :controller do
  describe '#create' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let(:stagers) { instance_double(VCAP::CloudController::Stagers) }
    let(:package) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid,
                                               type:  VCAP::CloudController::PackageModel::BITS_TYPE,
                                               state: VCAP::CloudController::PackageModel::READY_STATE)
    end
    let(:user) { set_current_user(user: VCAP::CloudController::User.make(guid: '1234'), email: 'dr@otter.com', user_name: 'dropper') }
    let(:space) { app_model.space }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_app).and_return(double(:stager, stage: nil))
      app_model.lifecycle_data.update(buildpack: nil, stack: VCAP::CloudController::Stack.default.name)
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
          app: { data: { guid: target_app_guid } }
        }
      }
    end
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    before do
      allow_user_read_access_for(user, spaces: [source_space, target_space])
      allow_user_write_access(user, space: target_space)
    end

    it 'returns a 201 OK response with the new droplet' do
      expect {
        post :copy, source_guid: source_droplet_guid, body: req_body
      }.to change { target_app.reload.droplets.count }.from(0).to(1)

      expect(response.status).to eq(201)
      expect(target_app.droplets.first.guid).to eq(parsed_body['guid'])
    end

    context 'when the request is invalid' do
      it 'returns a 422' do
        post :copy, source_guid: source_droplet_guid, body: { 'super_duper': 'bad_request' }

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
          post :copy, source_guid: source_droplet_guid, body: req_body

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user is a member of the space where source droplet exists' do
        before do
          allow_user_read_access_for(user, spaces: [source_space])
        end

        context 'when the user does not have read access to the target space' do
          before do
            disallow_user_read_access(user, space: target_space)
          end

          it 'returns a 404 ResourceNotFound error' do
            post :copy, source_guid: source_droplet_guid, body: req_body

            expect(response.status).to eq 404
            expect(response.body).to include 'ResourceNotFound'
          end
        end

        context 'when the user has read access, but not write access to the target space' do
          before do
            allow_user_read_access_for(user, spaces: [source_space, target_space])
            disallow_user_write_access(user, space: target_space)
          end

          it 'returns a forbidden error' do
            post :copy, source_guid: source_droplet_guid, body: req_body

            expect(response.status).to eq(403)
            expect(response.body).to include('NotAuthorized')
          end
        end
      end
    end

    context 'when the action raises errors' do
      before do
        allow_any_instance_of(VCAP::CloudController::DropletCopy).to receive(:copy).and_raise(VCAP::CloudController::DropletCopy::InvalidCopyError.new('boom'))
      end

      it 'returns an error ' do
        post :copy, source_guid: source_droplet_guid, body: req_body

        expect(response.status).to eq(422)
        expect(response.body).to include('boom')
      end
    end

    context 'when the source droplet does not exist' do
      let(:source_droplet_guid) { 'no-source-droplet-here' }
      it 'returns a not found error' do
        post :copy, source_guid: 'no droplet here', body: req_body

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
      end
    end

    context 'when the target application does not exist' do
      let(:target_app_guid) { 'not a real app guid' }
      it 'returns a not found error' do
        post :copy, source_guid: 'no droplet here', body: req_body

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
      allow_user_read_access_for(user, spaces: [space])
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
    let(:stagers) { instance_double(VCAP::CloudController::Stagers, stager_for_app: stager) }
    let(:stager) { instance_double(VCAP::CloudController::Diego::Stager, stop_stage: nil) }

    before do
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)
      CloudController::DependencyLocator.instance.register(:stagers, stagers)
    end

    it 'returns a 202 ACCEPTED and the job link in header' do
      delete :destroy, guid: droplet.guid

      expect(response.status).to eq(202)
      expect(response.body).to be_empty
      expect(response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))
    end

    it 'creates a job to track the deletion and returns it in the location header' do
      expect {
        delete :destroy, guid: droplet.guid
      }.to change {
        VCAP::CloudController::PollableJobModel.count
      }.by(1)

      job = VCAP::CloudController::PollableJobModel.last
      enqueued_job = Delayed::Job.last
      expect(job.delayed_job_guid).to eq(enqueued_job.guid)
      expect(job.operation).to eq('droplet.delete')
      expect(job.state).to eq('PROCESSING')
      expect(job.resource_guid).to eq(droplet.guid)
      expect(job.resource_type).to eq('droplet')

      expect(response.status).to eq(202)
      expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
    end

    it 'updates the job state when the job succeeds' do
      delete :destroy, guid: droplet.guid

      job = VCAP::CloudController::PollableJobModel.find(resource_guid: droplet.guid)
      expect(job).to_not be_nil, "Expected to find job with droplet guid '#{droplet.guid}' but did not"
      expect(job.state).to eq('PROCESSING')

      # one job to delete the model, which spawns another to delete the blob
      execute_all_jobs(expected_successes: 2, expected_failures: 0)

      expect(job.reload.state).to eq('COMPLETE')
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
    let!(:staging_droplet) { VCAP::CloudController::DropletModel.make(app_guid: app.guid, state: VCAP::CloudController::DropletModel::STAGING_STATE) }
    let!(:admin_droplet) { VCAP::CloudController::DropletModel.make }

    before do
      allow_user_read_access_for(user, spaces: [space])
    end

    it 'returns 200' do
      get :index
      expect(response.status).to eq(200)
    end

    it 'lists the droplets visible to the user' do
      get :index

      response_guids = parsed_body['resources'].map { |r| r['guid'] }
      expect(response_guids).to match_array([user_droplet_1, user_droplet_2].map(&:guid))
      expect(response_guids).not_to include(staging_droplet.guid)
    end

    it 'returns pagination links for /v3/droplets' do
      get :index
      expect(parsed_body['pagination']['first']['href']).to start_with("#{link_prefix}/v3/droplets")
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
        droplet_1 = VCAP::CloudController::DropletModel.make(app_guid: app.guid, state: VCAP::CloudController::DropletModel::STAGED_STATE)
        droplet_2 = VCAP::CloudController::DropletModel.make(app_guid: app.guid, state: VCAP::CloudController::DropletModel::STAGED_STATE)
        VCAP::CloudController::DropletModel.make

        get :index, app_guid: app.guid

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq(200)
        expect(response_guids).to match_array([droplet_1, droplet_2].map(&:guid))
      end

      it 'provides the correct base url in the pagination links' do
        get :index, app_guid: app.guid

        expect(parsed_body['pagination']['first']['href']).to include("#{link_prefix}/v3/apps/#{app.guid}/droplets")
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
      let!(:droplet_1) { VCAP::CloudController::DropletModel.make(package_guid: package.guid, state: VCAP::CloudController::DropletModel::STAGED_STATE) }

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
          expect(response.body).to include("Order by can only be: 'created_at', 'updated_at'")
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
          disallow_user_global_read_access(user)
        end

        it 'returns a 403 Not Authorized error' do
          get :index

          expect(response.status).to eq(403)
          expect(response.body).to include('NotAuthorized')
        end
      end

      context 'when the user has global read access' do
        before do
          allow_user_global_read_access(user)
        end

        it 'returns all droplets' do
          get :index

          expect(response.status).to eq(200)
          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response_guids).to match_array([user_droplet_1, user_droplet_2, admin_droplet].map(&:guid))
        end
      end

      context 'when the user has read access, but not write access to the space' do
        before do
          allow_user_read_access_for(user, spaces: [space])
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
