require 'spec_helper'
require 'perm'

RSpec.describe 'Perm', type: :integration, skip: ENV.fetch('CF_RUN_PERM_SPECS') { 'false' } != 'true' do
  include ControllerHelpers

  let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
  let(:assignee) { VCAP::CloudController::User.make }
  let(:uaa_target) { 'test.example.com' }
  let(:actor) { CloudFoundry::Perm::V1::Models::Actor.new(id: assignee.guid, issuer: uaa_target) }

  let(:perm_host) { ENV.fetch('PERM_RPC_HOST') { 'localhost:6283' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(perm_host) }

  before do
    TestConfig.config[:perm] = {
      enabled: true,
      host: perm_host
    }

    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).with([assignee.guid]).and_return({ assignee.guid => assignee.username })
    allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_return(uaa_target)
  end

  describe 'assigning organization roles' do
    let(:org) { VCAP::CloudController::Organization.make }

    describe 'PUT /v2/organizations/:guid/managers/:user_guid' do
      context 'as an admin' do
        it 'assigns the specified user to the org manager role' do
          set_current_user_as_admin(iss: uaa_target)

          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/organizations/#{org.guid}/managers/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "org-manager-#{org.guid}"
        end
      end
    end

    describe 'PUT /v2/organizations/:guid/auditors/:user_guid' do
      context 'as an admin' do
        it 'assigns the specified user to the org auditor role' do
          set_current_user_as_admin(iss: uaa_target)

          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/organizations/#{org.guid}/auditors/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "org-auditor-#{org.guid}"
        end
      end
    end

    describe 'PUT /v2/organizations/:guid/billing_managers/:user_guid' do
      context 'as an admin' do
        it 'assigns the specified user to the org billing manager role' do
          set_current_user_as_admin(iss: uaa_target)

          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/organizations/#{org.guid}/billing_managers/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "org-billing_manager-#{org.guid}"
        end
      end
    end

    describe 'PUT /v2/organizations/:guid/users/:user_guid' do
      context 'as an admin' do
        it 'assigns the specified user to the org user role' do
          set_current_user_as_admin(iss: uaa_target)

          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/organizations/#{org.guid}/users/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "org-user-#{org.guid}"
        end
      end
    end
  end

  describe 'assigning space roles' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }
    let(:space) {
      VCAP::CloudController::Space.make(
        organization: org,
      )
    }

    describe 'PUT /v2/spaces/:guid/managers/:user_guid' do
      context 'as an admin' do
        it 'assigns the specified user to the space manager role' do
          set_current_user_as_admin(iss: uaa_target)

          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/spaces/#{space.guid}/managers/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "space-manager-#{space.guid}"
        end
      end
    end

    describe 'PUT /v2/spaces/:guid/auditors/:user_guid' do
      context 'as an admin' do
        it 'assigns the specified user to the space auditor role' do
          set_current_user_as_admin(iss: uaa_target)

          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/spaces/#{space.guid}/auditors/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "space-auditor-#{space.guid}"
        end
      end
    end

    describe 'PUT /v2/spaces/:guid/developers/:user_guid' do
      context 'as an admin' do
        it 'assigns the specified user to the space developer role' do
          set_current_user_as_admin(iss: uaa_target)

          expect(client.list_actor_roles(actor)).to be_empty

          put "/v2/spaces/#{space.guid}/developers/#{assignee.guid}"
          expect(last_response.status).to eq(201), last_response.body

          roles = client.list_actor_roles(actor)
          expect(roles).not_to be_empty
          expect(roles[0].name).to eq "space-developer-#{space.guid}"
        end
      end
    end
  end
end
