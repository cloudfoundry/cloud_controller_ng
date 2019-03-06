require 'rails_helper'
require 'permissions_spec_helper'
require 'messages/deployment_create_message'

RSpec.describe DomainsController, type: :controller do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }

  describe '#create' do
    let(:request_body) do
      {
        "name": 'my-domain.biz',
        "internal": true
      }
    end

    describe 'for a valid user' do
      before do
        set_current_user_as_role(role: 'admin', user: user)
      end

      it 'returns a 201' do
        post :create, params: request_body, as: :json

        expect(response.status).to eq(201)

        createdDomain = VCAP::CloudController::Domain.last
        expect(createdDomain.name).to eq('my-domain.biz')
        expect(createdDomain.internal).to be_truthy

        expect(parsed_body['guid']).to eq(createdDomain.guid)
        expect(parsed_body['name']).to eq(createdDomain.name)
        expect(parsed_body['internal']).to eq(createdDomain.internal)
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) do
        {
          'admin' => 201,
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
      let(:api_call) { lambda { post :create, params: request_body, as: :json } }
    end

    it 'returns 401 for Unauthenticated requests' do
      post :create, params: request_body, as: :json
      expect(response.status).to eq(401)
    end
  end
end
