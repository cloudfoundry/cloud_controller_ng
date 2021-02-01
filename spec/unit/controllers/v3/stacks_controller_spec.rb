require 'rails_helper'
require 'actions/stack_create'
require 'permissions_spec_helper'

RSpec.describe StacksController, type: :controller do
  describe '#index' do
    before { VCAP::CloudController::Stack.dataset.destroy }
    let(:user) { VCAP::CloudController::User.make }

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 200,

        'reader_and_writer' => 200,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, user: user)

            get :index

            expect(response.status).to eq expected_return_value
          end
        end
      end

      it 'returns 401 when logged out' do
        get :index

        expect(response.status).to eq 401
      end
    end

    context 'when the user is logged in' do
      let!(:stack1) { VCAP::CloudController::Stack.make }
      let!(:stack2) { VCAP::CloudController::Stack.make }

      before do
        set_current_user(user)
      end

      it 'renders a paginated list of stacks' do
        get :index

        expect(parsed_body['resources'].first['guid']).to eq(stack1.guid)
        expect(parsed_body['resources'].second['guid']).to eq(stack2.guid)
      end

      it 'renders a name filtered list of stacks' do
        get :index, params: { names: stack2.name }

        expect(parsed_body['resources']).to have(1).stack
        expect(parsed_body['resources'].first['guid']).to eq(stack2.guid)
      end

      context 'when the query params are invalid' do
        it 'returns an error' do
          get :index, params: { per_page: 'whoops' }

          expect(response.status).to eq 400
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end
    end
  end

  describe '#show' do
    let(:user) { VCAP::CloudController::User.make }
    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 200,

        'reader_and_writer' => 200,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, user: user)

            get :index

            expect(response.status).to eq expected_return_value
          end
        end
      end

      it 'returns 401 when logged out' do
        get :index

        expect(response.status).to eq 401
      end
    end

    context 'when the user is logged in' do
      before do
        set_current_user(user)
      end

      context 'when the stack exists' do
        let!(:stack) { VCAP::CloudController::Stack.make }

        it 'renders a single stack details' do
          get :show, params: { guid: stack.guid }

          expect(response.status).to eq 200
          expect(parsed_body['guid']).to eq(stack.guid)
        end
      end

      context 'when the stack doesnt exist' do
        it 'errors' do
          get :show, params: { guid: 'psych!' }
          expect(response.status).to eq 404
          expect(response.body).to include('ResourceNotFound')
        end
      end
    end
  end

  describe '#create' do
    let(:user) { VCAP::CloudController::User.make }
    let(:req_body) do
      { name: 'the-name' }
    end

    before do
      set_current_user_as_admin(user: user)
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 201,

        'reader_and_writer' => 403,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, user: user)

            post :create, params: req_body, as: :json

            expect(response.status).to eq expected_return_value
          end
        end
      end
    end

    context 'when the message is not valid' do
      let(:req_body) { { name: '' } }

      it 'returns a 422 with the error message' do
        post :create, params: req_body, as: :json

        expect(response.status).to eq 422
        expect(parsed_body['errors'].first['detail']).to eq 'Name can\'t be blank'
      end
    end

    context 'when creating the stack fails' do
      before do
        mock_stack_create = instance_double(VCAP::CloudController::StackCreate)
        allow(mock_stack_create).to receive(:create).and_raise(VCAP::CloudController::StackCreate::Error.new('that did not work'))
        allow(VCAP::CloudController::StackCreate).to receive(:new).and_return(mock_stack_create)
      end

      it 'returns a 422 with the error message' do
        post :create, params: req_body, as: :json

        expect(response.status).to eq 422
        expect(parsed_body['errors'].first['detail']).to eq 'that did not work'
      end
    end
  end

  describe '#destroy' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let(:stack) { VCAP::CloudController::Stack.make }

    describe 'permissions' do
      context 'when the user does not have the write scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.read'])
        end

        it 'raises an ApiError with a 403 code' do
          delete :destroy, params: { guid: stack.guid }

          expect(response.status).to eq 403
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'permissions by role when the stack exists' do
        role_to_expected_http_response = {
          'admin' => 204,
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
                scopes: %w(cloud_controller.read cloud_controller.write)
              )
              delete :destroy, params: { guid: stack.guid }, as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      context 'permissions by role when the stack does not exist' do
        role_to_expected_http_response = {
          'admin' => 404,
          'reader_and_writer' => 404,
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
                user: user
              )
              delete :destroy, params: { guid: 'non-existent' }, as: :json

              expect(response.status).to eq expected_return_value
            end
          end
        end
      end

      it 'returns 401 when logged out' do
        delete :destroy, params: { guid: stack.guid }, as: :json

        expect(response.status).to eq 401
      end
    end

    context 'when the user is logged in with sufficient permissions' do
      before do
        set_current_user_as_admin(user: user)
      end

      context 'when stack is not found' do
        it 'returns a 404' do
          delete :destroy, params: { guid: 'not-a-real-guid' }

          expect(response.status).to eq 404
        end
      end

      context 'when stack has apps associated with it' do
        before do
          VCAP::CloudController::ProcessModelFactory.make(stack: stack)
        end

        it 'does not delete the stack' do
          delete :destroy, params: { guid: stack.guid }

          expect(stack).to exist
        end

        it 'returns 422' do
          delete :destroy, params: { guid: stack.guid }

          expect(response.status).to eq 422
        end

        it 'returns 10008 UnprocessableEntity' do
          delete :destroy, params: { guid: stack.guid }

          expect(parsed_body['errors'].first['code']).to eq 10008
        end
      end
    end

    context 'when user is logged in with insufficient permissions' do
      it 'does not delete the stack' do
        delete :destroy, params: { guid: stack.guid }

        expect(stack).to exist
      end
    end
  end

  describe '#update' do
    let!(:org) { VCAP::CloudController::Organization.make(name: "Harold's Farm") }
    let!(:space) { VCAP::CloudController::Space.make(name: 'roosters', organization: org) }
    let(:user) { VCAP::CloudController::User.make }
    let(:stack) { VCAP::CloudController::Stack.make }

    let(:labels) do
      {
        fruit: 'pears',
        truck: 'hino'
      }
    end
    let(:annotations) do
      {
        potato: 'celandine',
        beet: 'formanova',
      }
    end
    let!(:update_message) do
      {
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
      VCAP::CloudController::LabelsUpdate.update(stack, labels, VCAP::CloudController::StackLabelModel)
      VCAP::CloudController::AnnotationsUpdate.update(stack, annotations, VCAP::CloudController::StackAnnotationModel)
    end

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      it 'updates the stack' do
        patch :update, params: { guid: stack.guid }.merge(update_message), as: :json

        expect(response.status).to eq(200)
        expect(parsed_body['metadata']['labels']).to eq({ 'fruit' => 'passionfruit', 'truck' => 'hino' })
        expect(parsed_body['metadata']['annotations']).to eq({ 'potato' => 'adora', 'beet' => 'formanova' })

        stack.reload
        expect(stack).to have_labels(
          { key: 'fruit', value: 'passionfruit' },
          { key: 'truck', value: 'hino' }
        )
        expect(stack).to have_annotations(
          { key: 'potato', value: 'adora' },
          { key: 'beet', value: 'formanova' }
        )
      end

      context 'when a label is deleted' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                fruit: nil
              }
            }
          }
        end

        it 'succeeds' do
          patch :update, params: { guid: stack.guid }.merge(request_body), as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['labels']).to eq({ 'truck' => 'hino' })
          expect(stack).to have_labels({ key: 'truck', value: 'hino' })
        end
      end
      context 'when an empty request is sent' do
        let(:request_body) do
          {}
        end

        it 'succeeds' do
          patch :update, params: { guid: stack.guid }.merge(request_body), as: :json
          expect(response.status).to eq(200)
          stack.reload
          expect(parsed_body['guid']).to eq(stack.guid)
        end
      end

      context 'when the message is invalid' do
        before do
          set_current_user_as_admin
        end
        let!(:update_message2) { update_message.merge({ animals: 'Cows' }) }

        it 'fails' do
          patch :update, params: { guid: stack.guid }.merge(update_message2), as: :json
          expect(response.status).to eq(422)
        end
      end

      context 'when there is no such stack' do
        it 'fails' do
          patch :update, params: { guid: "Greg's missing stack" }.merge(update_message), as: :json

          expect(response.status).to eq(404)
        end
      end

      context 'when there is an invalid label' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'cloudfoundry.org/label': 'value'
              }
            }
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: stack.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/label [\w\s]+ error/)
        end
      end

      context 'when there is an invalid annotation' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                key: 'big' * 5000
              }
            }
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: stack.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/is greater than 5000 characters/)
        end
      end

      context 'when there are too many annotations' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }
        end

        before do
          VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 2)
        end

        it 'fails with a 422' do
          patch :update, params: { guid: stack.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/exceed maximum of 2/)
        end
      end

      context 'when an annotation is deleted' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                potato: nil
              }
            }
          }
        end

        it 'succeeds' do
          patch :update, params: { guid: stack.guid }.merge(request_body), as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['annotations']).to eq({ 'beet' => 'formanova' })

          stack.reload
          expect(stack).to have_annotations({ key: 'beet', value: 'formanova' })
        end
      end
    end

    context 'when the user is not an admin' do
      before do
        set_current_user(user)
      end

      context 'and the stack does not exist' do
        it 'returns a 404' do
          patch :update, params: { guid: 'bogus-stack-gyud' }.merge({}), as: :json

          expect(response.status).to eq(404)
        end
      end
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 403,
            'global_auditor' => 403,
            'space_developer' => 403,
            'space_manager' => 403,
            'space_auditor' => 403,
            'org_manager' => 403,
            'org_auditor' => 403,
            'org_billing_manager' => 403,
          }
        end
        let(:api_call) { lambda { patch :update, params: { guid: stack.guid }.merge(update_message), as: :json } }
      end
    end
  end
end
