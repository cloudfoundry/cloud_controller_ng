require 'spec_helper'
require 'perm'

include ControllerHelpers

RSpec.describe 'Perm', type: :integration do
  let(:org) { Organization.make }
  let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
  let(:user_email) { Sham.email }

  let(:perm_host) { ENV.fetch('PERM_RPC_HOST') { 'localhost:6283' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(perm_host) }

  before do
    TestConfig.config[:perm][:host] = perm_host
  end

  describe 'PUT /v2/organizations/:guid/managers/:user_guid' do
    let(:org_manager) { User.make }

    describe 'removing the last org manager' do
      context 'as an admin' do
        it 'is allowed' do
          set_current_user_as_admin

          expect(client.list_actor_roles(org_manager.guid)).to be_empty

          put "/v2/organizations/#{org.guid}/managers/#{org_manager.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(org_manager.guid)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "org-manager-#{org.guid}"
        end
      end
    end
  end
end
