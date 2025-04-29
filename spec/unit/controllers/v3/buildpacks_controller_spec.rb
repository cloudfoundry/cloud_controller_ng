require 'rails_helper'
require 'messages/buildpack_create_message'
require 'models/runtime/buildpack'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe BuildpacksController, type: :controller do
  before do
    TestConfig.override(kubernetes: {})
  end

  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 200,
        'space_developer' => 200,
        'space_manager' => 200,
        'space_auditor' => 200,
        'org_manager' => 200,
        'admin_read_only' => 200,
        'global_auditor' => 200,
        'org_auditor' => 200,
        'org_billing_manager' => 200,
        'org_user' => 200
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:org) { VCAP::CloudController::Organization.make }
          let(:space) { VCAP::CloudController::Space.make(organization: org) }

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role:, org:, space:, user:)

            get :index

            expect(response.status).to eq expected_return_value
          end
        end
      end

      it 'returns 401 when logged out' do
        get :index

        expect(response).to have_http_status :unauthorized
      end
    end

    context 'when the user is logged in' do
      let!(:stack1) { VCAP::CloudController::Stack.make }
      let!(:stack2) { VCAP::CloudController::Stack.make }

      let!(:buildpack1) { VCAP::CloudController::Buildpack.make(stack: stack1.name, position: 2) }
      let!(:buildpack2) { VCAP::CloudController::Buildpack.make(stack: stack2.name, position: 1) }
      let!(:buildpack3) { VCAP::CloudController::Buildpack.make(stack: stack1.name, lifecycle: 'cnb', position: 1) }

      before do
        set_current_user(user)
      end

      it 'renders a paginated list of buildpacks' do
        get :index

        expect(parsed_body['resources'].first['guid']).to eq(buildpack2.guid)
        expect(parsed_body['resources'].second['guid']).to eq(buildpack1.guid)
        expect(parsed_body['resources'].third['guid']).to eq(buildpack3.guid)
      end

      it 'renders a lifecycle filtered list of buildpacks' do
        get :index, params: { lifecycle: 'cnb' }

        expect(parsed_body['resources'].first['guid']).to eq(buildpack3.guid)
      end

      it 'renders a name filtered list of buildpacks' do
        get :index, params: { names: buildpack2.name }

        expect(parsed_body['resources']).to have(1).buildpack
        expect(parsed_body['resources'].first['guid']).to eq(buildpack2.guid)
      end

      it 'renders a stack filtered list of buildpacks' do
        get :index, params: { stacks: stack2.name }

        expect(parsed_body['resources']).to have(1).buildpack
        expect(parsed_body['resources'].first['guid']).to eq(buildpack2.guid)
      end

      it 'renders an ordered list of buildpacks' do
        get :index, params: { order_by: '-position' }

        expect(parsed_body['resources']).to have(3).buildpack
        expect(parsed_body['resources'].first['position']).to eq(2)
        expect(parsed_body['resources'].second['position']).to eq(1)
        expect(parsed_body['resources'].third['position']).to eq(1)
      end

      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::BuildpackListFetcher).to receive(:fetch_all).with(
          anything, hash_including(eager_loaded_associations: %i[labels annotations])
        ).and_call_original

        get :index

        expect(response).to have_http_status(:ok)
      end

      context 'when the query params are invalid' do
        it 'returns an error' do
          get :index, params: { per_page: 'whoops' }

          expect(response).to have_http_status :bad_request
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end
    end
  end

  describe '#destroy' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:user) { VCAP::CloudController::User.make }

    describe 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          delete :destroy, params: { guid: buildpack.guid }

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'permissions by role when the buildpack exists' do
        role_to_expected_http_response = {
          'admin' => 202,
          'reader_and_writer' => 403
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            let(:org) { VCAP::CloudController::Organization.make }
            let(:space) { VCAP::CloudController::Space.make(organization: org) }

            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role: role,
                org: org,
                space: space,
                user: user,
                scopes: %w[cloud_controller.read cloud_controller.write]
              )
              delete :destroy, params: { guid: buildpack.guid }, as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      context 'permissions by role when the buildpack does not exist' do
        role_to_expected_http_response = {
          'admin' => 404,
          'reader_and_writer' => 404
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            let(:org) { VCAP::CloudController::Organization.make }
            let(:space) { VCAP::CloudController::Space.make(organization: org) }

            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role:,
                org:,
                space:,
                user:
              )
              delete :destroy, params: { guid: 'non-existent' }, as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      it 'returns 401 when logged out' do
        delete :destroy, params: { guid: buildpack.guid }, as: :json

        expect(response).to have_http_status :unauthorized
      end
    end

    context 'as an admin user' do
      before do
        set_current_user_as_admin(user:)
      end

      context 'when the buildpack exists' do
        it 'creates a job to track the deletion and returns it in the location header' do
          expect do
            delete :destroy, params: { guid: buildpack.guid }
          end.to change(VCAP::CloudController::PollableJobModel, :count).by(1)

          job = VCAP::CloudController::PollableJobModel.last
          enqueued_job = Delayed::Job.last
          expect(job.delayed_job_guid).to eq(enqueued_job.guid)
          expect(job.operation).to eq('buildpack.delete')
          expect(job.state).to eq('PROCESSING')
          expect(job.resource_guid).to eq(buildpack.guid)
          expect(job.resource_type).to eq('buildpack')

          expect(response).to have_http_status(:accepted)
          expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
        end

        it 'updates the job state when the job succeeds' do
          delete :destroy, params: { guid: buildpack.guid }

          job = VCAP::CloudController::PollableJobModel.find(resource_guid: buildpack.guid)
          expect(job).not_to be_nil
          expect(job.state).to eq('PROCESSING')

          # one job to delete the model, which spawns another to delete the blob
          execute_all_jobs(expected_successes: 2, expected_failures: 0)

          expect(job.reload.state).to eq('COMPLETE')
        end
      end

      context 'when the buildpack does not exist' do
        it 'returns a 404 Not Found' do
          delete :destroy, params: { guid: 'not-found' }

          expect(response).to have_http_status(:not_found)
          expect(response.body).to include('ResourceNotFound')
        end
      end
    end
  end

  describe '#show' do
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
    end

    context 'when the buildpack exists' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make }

      it 'renders a single buildpack details' do
        get :show, params: { guid: buildpack.guid }
        expect(response).to have_http_status :ok
        expect(parsed_body['guid']).to eq(buildpack.guid)
      end
    end

    context 'when the buildpack does not exist' do
      it 'errors' do
        get :show, params: { guid: 'psych!' }
        expect(response).to have_http_status :not_found
        expect(response.body).to include('ResourceNotFound')
      end
    end
  end

  describe '#create' do
    before do
      VCAP::CloudController::Buildpack.make
      VCAP::CloudController::Buildpack.make
      VCAP::CloudController::Buildpack.make
    end

    context 'when authorized' do
      let(:user) { VCAP::CloudController::User.make }
      let(:stack) { VCAP::CloudController::Stack.make }
      let(:params) do
        {
          name: 'the-r3al_Name',
          stack: stack.name,
          position: 2,
          enabled: false,
          locked: true,
          metadata: {
            labels: {
              fruit: 'passionfruit'
            },
            annotations: {
              potato: 'adora'
            }
          }
        }
      end

      before do
        set_current_user_as_admin(user:)
      end

      context 'when params are correct' do
        context 'when the stack exists' do
          let(:stack) { VCAP::CloudController::Stack.make }

          it 'saves the buildpack in the database' do
            post :create, params: params, as: :json

            buildpack_id = parsed_body['guid']
            our_buildpack = VCAP::CloudController::Buildpack.find(guid: buildpack_id)
            expect(our_buildpack).not_to be_nil
            expect(our_buildpack.name).to eq(params[:name])
            expect(our_buildpack.stack).to eq(params[:stack])
            expect(our_buildpack.position).to eq(params[:position])
            expect(our_buildpack.enabled).to eq(params[:enabled])
            expect(our_buildpack.locked).to eq(params[:locked])
            expect(our_buildpack.labels[0].key_name).to eq('fruit')
            expect(our_buildpack.annotations[0].value).to eq('adora')
          end
        end

        context 'when the stack does not exist' do
          let(:stack) { double(:stack, name: 'does-not-exist') }

          it 'does not create the buildpack' do
            expect { post :create, params: params, as: :json }.
              not_to(change(VCAP::CloudController::Buildpack, :count))
          end

          it 'returns 422' do
            post :create, params: params, as: :json

            expect(response).to have_http_status :unprocessable_entity
          end

          it 'returns a helpful error message' do
            post :create, params: params, as: :json

            expect(parsed_body['errors'][0]['detail']).to include("Stack '#{stack.name}' does not exist")
          end
        end
      end

      context 'when params are invalid' do
        before do
          allow_any_instance_of(VCAP::CloudController::BuildpackCreateMessage).
            to receive(:valid?).and_return(false)
        end

        it 'returns 422' do
          post :create, params: params, as: :json

          expect(response).to have_http_status :unprocessable_entity
        end

        it 'does not create the buildpack' do
          expect { post :create, params: params, as: :json }.
            not_to(change(VCAP::CloudController::Buildpack, :count))
        end
      end
    end
  end

  describe '#update' do
    let(:user) { VCAP::CloudController::User.make }
    let(:buildpack) do
      VCAP::CloudController::Buildpack.make(stack: nil)
    end

    describe 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          patch :update, params: { guid: buildpack.guid }

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'permissions by role when the buildpack exists' do
        role_to_expected_http_response = {
          'admin' => 200,
          'reader_and_writer' => 403
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            let(:org) { VCAP::CloudController::Organization.make }
            let(:space) { VCAP::CloudController::Space.make(organization: org) }

            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role: role,
                org: org,
                space: space,
                user: user,
                scopes: %w[cloud_controller.read cloud_controller.write]
              )
              patch :update, params: { guid: buildpack.guid }, as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      context 'permissions by role when the buildpack does not exist' do
        role_to_expected_http_response = {
          'admin' => 404,
          'reader_and_writer' => 404
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            let(:org) { VCAP::CloudController::Organization.make }
            let(:space) { VCAP::CloudController::Space.make(organization: org) }

            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role:,
                org:,
                space:,
                user:
              )
              patch :update, params: { guid: 'non-existent' }, as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      it 'returns 401 when logged out' do
        patch :update, params: { guid: buildpack.guid }, as: :json

        expect(response).to have_http_status :unauthorized
      end
    end

    context 'when authenticated' do
      let(:name) do
        expect(buildpack.reload.enabled).to be false
      end

      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      before do
        set_current_user_as_admin(user:)
      end

      context 'when the request message has invalid parameters' do
        it 'returns 422' do
          patch :update, params: { guid: buildpack.guid, enabled: 'totally-not-a-valid-value' }, as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(parsed_body['errors'][0]['detail']).to include('Enabled must be a boolean')
        end
      end

      context 'when there are model level validation failures' do
        it 'returns 422' do
          other_buildpack = VCAP::CloudController::Buildpack.make(stack: buildpack.stack)
          patch :update, params: { guid: buildpack.guid, name: other_buildpack.name }, as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(parsed_body['errors'][0]['detail']).to include("Buildpack with name '#{other_buildpack.name}' and an unassigned stack already exists")
        end
      end

      it 'updates the updatable fields' do
        buildpack
        other_buildpack = VCAP::CloudController::Buildpack.make
        new_stack = VCAP::CloudController::Stack.make
        new_values = {
          name: 'new-name',
          stack: new_stack.name,
          position: other_buildpack.position,
          enabled: !buildpack.enabled,
          locked: !buildpack.locked,
          metadata: {
            labels: { key: 'value' },
            annotations: { key2: 'value2' }
          }
        }
        patch :update, params: { guid: buildpack.guid }.merge(new_values), as: :json

        expect(response).to have_http_status :ok

        expect(parsed_body['name']).to eq 'new-name'
        expect(parsed_body['stack']).to eq new_stack.name
        expect(parsed_body['position']).to eq other_buildpack.position
        expect(parsed_body['enabled']).to eq !buildpack.enabled
        expect(parsed_body['locked']).to eq !buildpack.locked
        expect(parsed_body['metadata']).to eq({ 'labels' => { 'key' => 'value' }, 'annotations' => { 'key2' => 'value2' } })

        buildpack.reload
        expect(buildpack.name).to eq 'new-name'
        expect(buildpack.stack).to eq new_stack.name
        expect(buildpack.position).to eq other_buildpack.position
        expect(buildpack.enabled).to eq parsed_body['enabled']
        expect(buildpack.locked).to eq parsed_body['locked']
      end
    end
  end

  describe '#upload' do
    let(:stat_double) { instance_double(File::Stat, size: 2) }
    let(:test_buildpack) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'upload_binary_buildpack', stack: nil, position: 0 }) }
    let(:user) { VCAP::CloudController::User.make }
    let(:uploader) { instance_double(VCAP::CloudController::BuildpackUpload, upload_async: nil) }
    let(:buildpack_bits_path) { '/tmp/buildpack_bits_path' }
    let(:buildpack_bits_name) { 'buildpack.zip' }

    before do
      allow(File).to receive_messages(
        stat: stat_double,
        read: "PK\x03\x04".force_encoding('binary')
      )
    end

    describe 'permissions' do
      let(:params) { { bits_path: buildpack_bits_path, bits_name: buildpack_bits_name } }

      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          post :upload, params: params.merge({ guid: test_buildpack.guid })

          expect(response).to have_http_status :forbidden
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'permissions by role when the buildpack exists' do
        role_to_expected_http_response = {
          'admin' => 202,
          'reader_and_writer' => 403
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            let(:org) { VCAP::CloudController::Organization.make }
            let(:space) { VCAP::CloudController::Space.make(organization: org) }

            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role: role,
                org: org,
                space: space,
                user: user,
                scopes: %w[cloud_controller.read cloud_controller.write]
              )
              post :upload, params: params.merge({ guid: test_buildpack.guid }), as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      context 'permissions by role when the buildpack does not exist' do
        role_to_expected_http_response = {
          'admin' => 404,
          'reader_and_writer' => 404
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            let(:org) { VCAP::CloudController::Organization.make }
            let(:space) { VCAP::CloudController::Space.make(organization: org) }

            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role:,
                org:,
                space:,
                user:
              )
              post :upload, params: params.merge({ guid: 'doesnt-exist' }), as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      it 'returns 401 when logged out' do
        post :upload, params: params.merge({ guid: test_buildpack.guid }), as: :json

        expect(response).to have_http_status :unauthorized
      end
    end

    describe 'when the user has permission to upload a buildpack' do
      let(:params) { { guid: test_buildpack.guid, bits_path: buildpack_bits_path, bits_name: buildpack_bits_name } }

      before do
        set_current_user_as_admin(user:)
      end

      it 'returns a 202, the buildpack, and the job location header' do
        expect do
          post :upload, params: params.merge({}), as: :json
        end.to change(VCAP::CloudController::PollableJobModel, :count).by(1)

        job = VCAP::CloudController::PollableJobModel.last
        expect(job.operation).to eq('buildpack.upload')
        expect(response.status).to eq(202), response.body
        expect(Oj.load(response.body)['guid']).to eq(test_buildpack.guid)
        expect(response.headers['Location']).to include "#{link_prefix}/v3/jobs/#{job.guid}"
        expect(test_buildpack.reload.state).to eq(VCAP::CloudController::Buildpack::CREATED_STATE)
      end

      context 'when the buildpack is locked' do
        let(:bp) { VCAP::CloudController::Buildpack.make(locked: true) }

        it 'returns a 422 and error message that the buildpack is locked' do
          post :upload, params: { guid: bp.guid, bits_path: buildpack_bits_path, bits_name: buildpack_bits_name }.merge({}), as: :json
          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'UnprocessableEntity'
        end
      end

      context 'when the buildpack upload message is not valid' do
        let(:params) { { guid: test_buildpack.guid, bits_path: nil } }

        it 'errors' do
          post :upload, params: params.merge({}), as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include('UnprocessableEntity')
        end
      end

      context 'when nginx_upload_dummy is present' do
        let(:params) { { guid: test_buildpack.guid, VCAP::CloudController::Constants::INVALID_NGINX_UPLOAD_PARAM => '' } }

        it 'errors' do
          post :upload, params: params.merge({}), as: :json

          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include('UnprocessableEntity')
        end
      end
    end
  end
end
