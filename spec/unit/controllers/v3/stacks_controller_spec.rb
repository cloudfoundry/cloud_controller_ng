require 'rails_helper'
require 'actions/stack_create'

RSpec.describe StacksController, type: :controller do
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
end
