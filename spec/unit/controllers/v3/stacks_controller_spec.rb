require 'rails_helper'
require 'actions/stack_create'

RSpec.describe StacksController, type: :controller do
  describe '#index' do
    before { VCAP::CloudController::Stack.dataset.destroy }
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
        'org_user' => 200,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:org) { VCAP::CloudController::Organization.make }
          let(:space) { VCAP::CloudController::Space.make(organization: org) }

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

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
        'space_developer' => 200,
        'space_manager' => 200,
        'space_auditor' => 200,
        'org_manager' => 200,
        'admin_read_only' => 200,
        'global_auditor' => 200,
        'org_auditor' => 200,
        'org_billing_manager' => 200,
        'org_user' => 200,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:org) { VCAP::CloudController::Organization.make }
          let(:space) { VCAP::CloudController::Space.make(organization: org) }

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

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
      { 'name': 'the-name' }
    end

    before do
      set_current_user_as_admin(user: user)
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 201,
        'org_manager' => 403,
        'admin_read_only' => 403,
        'org_auditor' => 403,
        'org_billing_manager' => 403,
        'org_user' => 403,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:org) { VCAP::CloudController::Organization.make }

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, user: user)

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

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 204,
        'space_developer' => 404,
        'space_manager' => 404,
        'space_auditor' => 404,
        'org_manager' => 404,
        'admin_read_only' => 403,
        'global_auditor' => 403,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
        'org_user' => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:org) { VCAP::CloudController::Organization.make }
          let(:space) { VCAP::CloudController::Space.make(organization: org) }

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            delete :destroy, params: { guid: stack.guid }

            expect(response.status).to eq expected_return_value
          end
        end
      end

      it 'returns 401 when logged out' do
        delete :destroy, params: { guid: stack.guid }

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
end
