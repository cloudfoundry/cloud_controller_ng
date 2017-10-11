require 'spec_helper'
require 'perm'
require 'perm_test_helpers'

RSpec.describe 'Perm', type: :integration, skip: ENV['CF_RUN_PERM_SPECS'] != 'true' do
  perm_server = nil

  ORG_ROLES = [:user, :manager, :auditor, :billing_manager].freeze
  SPACE_ROLES = [:developer, :manager, :auditor].freeze

  include ControllerHelpers

  let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
  let(:assignee) { VCAP::CloudController::User.make(username: 'not-really-a-person') }
  let(:uaa_target) { 'test.example.com' }

  let(:perm_hostname) { perm_server.hostname.clone }
  let(:perm_port) { perm_server.port.clone }

  let(:ca_certs) { [perm_server.tls_ca.clone] }

  let(:client) { CloudFoundry::Perm::V1::Client.new(hostname: perm_hostname, port: perm_port, trusted_cas: ca_certs) }
  let(:issuer) { 'https://auth.example.com/oauth/token' }

  if ENV['CF_RUN_PERM_SPECS'] == 'true'
    before(:each) do
      perm_server = CloudFoundry::PermTestHelpers::ServerRunner.new
      perm_server.start
    end

    after(:each) do
      perm_server.stop
    end
  end

  before do
    TestConfig.config[:perm] = {
      enabled: true,
      hostname: perm_hostname,
      port: perm_port,
      ca_cert_path: perm_server.tls_ca_path
    }

    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).with([assignee.guid]).and_return({ assignee.guid => assignee.username })
    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:id_for_username).with(assignee.username).and_return(assignee.guid)
    allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_return(issuer)

    set_current_user_as_admin(iss: issuer)
  end

  describe 'POST /v2/organizations' do
    ORG_ROLES.each do |role|
      it "creates the org-#{role}-<org_id> role" do
        post '/v2/organizations', { name: 'v2-org' }.to_json

        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        org_id = json_body['metadata']['guid']
        role_name = "org-#{role}-#{org_id}"

        role = client.get_role(role_name)
        expect(role.name).to eq(role_name)
        expect(role.id).not_to be_nil
      end

      it 'does not allow the user to create an org that already exists' do
        body = { name: 'v2-org' }.to_json
        post '/v2/organizations', body

        expect(last_response.status).to eq(201)

        post '/v2/organizations', body

        expect(last_response.status).to eq(400)

        json_body = JSON.parse(last_response.body)
        expect(json_body['error_code']).to eq('CF-OrganizationNameTaken')
      end
    end
  end

  describe 'DELETE /v2/organizations/:guid' do
    let(:worker) { Delayed::Worker.new }

    ORG_ROLES.each do |role|
      describe 'when the org does not have spaces' do
        describe 'synchronous deletion' do
          it "deletes the org-#{role}-<org_id> role" do
            post '/v2/organizations', { name: 'v2-org' }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)
            org_id = json_body['metadata']['guid']
            role_name = "org-#{role}-#{org_id}"

            delete "/v2/organizations/#{org_id}"

            expect(last_response.status).to eq(204)

            expect {
              client.get_role(role_name)
            }.to raise_error GRPC::NotFound
          end
        end

        describe 'async deletion' do
          it "deletes the org-#{role}-<org_id> role" do
            post '/v2/organizations', { name: 'v2-org' }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)
            org_id = json_body['metadata']['guid']
            role_name = "org-#{role}-#{org_id}"

            delete "/v2/organizations/#{org_id}?async=true"

            expect(last_response.status).to eq(202)

            succeeded_jobs, failed_jobs = worker.work_off
            expect(succeeded_jobs).to be > 0
            expect(failed_jobs).to equal(0)

            expect {
              client.get_role(role_name)
            }.to raise_error GRPC::NotFound
          end
        end
      end

      describe 'when the org has spaces' do
        describe 'without "recursive" param' do
          it 'alerts the user without deleting any roles' do
            post '/v2/organizations', { name: 'v2-org' }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)
            org_id = json_body['metadata']['guid']
            org_role_name = "org-#{role}-#{org_id}"

            post '/v2/spaces', {
              name: 'v2-space',
              organization_guid: org_id
            }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)
            space_id = json_body['metadata']['guid']
            space_role_name = "space-developer-#{space_id}"

            delete "/v2/organizations/#{org_id}?recursive=false"

            expect(last_response.status).to eq(400)

            expect {
              client.get_role(org_role_name)
            }.not_to raise_error
            expect {
              client.get_role(space_role_name)
            }.not_to raise_error
          end
        end

        describe 'with "recursive" param' do
          describe 'synchronous deletion' do
            it 'deletes the roles recursively' do
              post '/v2/organizations', { name: 'v2-org' }.to_json

              expect(last_response.status).to eq(201)

              json_body = JSON.parse(last_response.body)
              org_id = json_body['metadata']['guid']
              org_role_name = "org-#{role}-#{org_id}"

              post '/v2/spaces', {
                name: 'v2-space',
                organization_guid: org_id
              }.to_json

              expect(last_response.status).to eq(201)

              json_body = JSON.parse(last_response.body)
              space_id = json_body['metadata']['guid']
              space_role_name = "space-developer-#{space_id}"

              delete "/v2/organizations/#{org_id}?recursive=true"

              expect(last_response.status).to eq(204)

              expect {
                client.get_role(org_role_name)
              }.to raise_error GRPC::NotFound
              expect {
                client.get_role(space_role_name)
              }.to raise_error GRPC::NotFound
            end
          end

          describe 'async deletion' do
            it 'deletes the roles recursively' do
              post '/v2/organizations', { name: 'v2-org' }.to_json

              expect(last_response.status).to eq(201)

              json_body = JSON.parse(last_response.body)
              org_id = json_body['metadata']['guid']
              org_role_name = "org-#{role}-#{org_id}"

              post '/v2/spaces', {
                name: 'v2-space',
                organization_guid: org_id
              }.to_json

              expect(last_response.status).to eq(201)

              json_body = JSON.parse(last_response.body)
              space_id = json_body['metadata']['guid']
              space_role_name = "space-developer-#{space_id}"

              delete "/v2/organizations/#{org_id}?recursive=true&async=true"

              expect(last_response.status).to eq(202)

              succeeded_jobs, failed_jobs = worker.work_off
              expect(succeeded_jobs).to be > 0
              expect(failed_jobs).to equal(0)

              expect {
                client.get_role(org_role_name)
              }.to raise_error GRPC::NotFound
              expect {
                client.get_role(space_role_name)
              }.to raise_error GRPC::NotFound
            end
          end
        end
      end

      it 'alerts the user if the org does not exist' do
        post '/v2/organizations', { name: 'v2-org' }.to_json
        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        org_id = json_body['metadata']['guid']

        delete "/v2/organizations/#{org_id}"
        expect(last_response.status).to eq(204)

        delete "/v2/organizations/#{org_id}"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'PUT /v2/organizations/:guid/:role/:user_guid' do
    let(:org) { VCAP::CloudController::Organization.make }

    ORG_ROLES.each do |role|
      describe "PUT /v2/organizations/:guid/#{role}s/:user_guid" do
        let(:role_name) { "org-#{role}-#{org.guid}" }

        before do
          client.create_role role_name
        end

        it "assigns the specified user to the org #{role} role" do
          expect(client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)).to be_empty

          put "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          expect(client.has_role?(role_name: role_name, actor_id: assignee.guid, issuer: issuer)).to be(true)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles.length).to be(1)
        end

        it 'does nothing when the user is assigned to the role a second time' do
          expect(client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)).to be_empty

          put "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          put "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          expect(client.has_role?(role_name: role_name, actor_id: assignee.guid, issuer: issuer)).to be(true)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles.length).to be(1)
        end
      end
    end
  end

  describe 'DELETE /v2/organizations/:guid/:role' do
    let(:org) { VCAP::CloudController::Organization.make }

    ORG_ROLES.each do |role|
      describe "DELETE /v2/organizations/:guid/#{role}s" do
        let(:role_name) { "org-#{role}-#{org.guid}" }

        before do
          client.create_role role_name
        end

        it "removes the user from the org #{role} role" do
          client.assign_role(role_name: role_name, actor_id: assignee.guid, issuer: issuer)

          delete "/v2/organizations/#{org.guid}/#{role}s", { 'username' => assignee.username }.to_json
          expect(last_response.status).to eq(204)

          expect(client.has_role?(role_name: role_name, actor_id: assignee.guid, issuer: issuer)).to be(false)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles).to be_empty
        end

        it "does nothing if the user does not have the org #{role} role" do
          delete "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)
        end
      end
    end

    describe 'DELETE /v2/organizations/:guid/users?recursive=true' do
      let!(:org1) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }
      let!(:org2) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }
      let!(:org1_space) { VCAP::CloudController::Space.make(organization: org1) }
      let!(:org2_space) { VCAP::CloudController::Space.make(organization: org2) }

      before do
        client.create_role("org-user-#{org1.guid}")
        client.assign_role(role_name: "org-user-#{org1.guid}", actor_id: assignee.guid, issuer: issuer)
        client.create_role("org-user-#{org2.guid}")
        client.assign_role(role_name: "org-user-#{org2.guid}", actor_id: assignee.guid, issuer: issuer)

        SPACE_ROLES.each do |role|
          client.create_role("space-#{role}-#{org1_space.guid}")
          put "/v2/spaces/#{org1_space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)
          client.create_role("space-#{role}-#{org2_space.guid}")
          put "/v2/spaces/#{org2_space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)
        end
      end

      it 'removes the user from all org and space roles for that org and no other' do
        delete "/v2/organizations/#{org1.guid}/users?recursive=true", { 'username' => assignee.username }.to_json
        expect(last_response.status).to eq(204)

        ORG_ROLES.each do |role|
          expect(client.has_role?(role_name: "org-#{role}-#{org1.guid}", actor_id: assignee.guid, issuer: issuer)).to be(false)
        end

        expect(client.has_role?(role_name: "org-user-#{org2.guid}", actor_id: assignee.guid, issuer: issuer)).to be(true)

        SPACE_ROLES.each do |role|
          expect(client.has_role?(role_name: "space-#{role}-#{org1_space.guid}", actor_id: assignee.guid, issuer: issuer)).to be(false)
          expect(client.has_role?(role_name: "space-#{role}-#{org2_space.guid}", actor_id: assignee.guid, issuer: issuer)).to be(true)
        end
      end
    end
  end

  describe 'DELETE /v2/organizations/:guid/:role/:user_guid' do
    let(:org) { VCAP::CloudController::Organization.make }

    ORG_ROLES.each do |role|
      describe "DELETE /v2/organizations/:guid/#{role}s/:user_guid" do
        let(:role_name) { "org-#{role}-#{org.guid}" }

        before do
          client.create_role role_name
        end

        it "removes the user from the org #{role} role" do
          client.assign_role(role_name: role_name, actor_id: assignee.guid, issuer: issuer)

          delete "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)

          expect(client.has_role?(role_name: role_name, actor_id: assignee.guid, issuer: issuer)).to be(false)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles).to be_empty
        end

        it "does nothing if the user does not have the org #{role} role" do
          delete "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  describe 'POST /v2/spaces' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }

    SPACE_ROLES.each do |role|
      it "creates the space-#{role}-<space_id> role" do
        post '/v2/spaces', {
          name: 'v2-space',
          organization_guid: org.guid
        }.to_json

        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        space_id = json_body['metadata']['guid']
        role_name = "space-#{role}-#{space_id}"

        role = client.get_role(role_name)
        expect(role.name).to eq(role_name)
        expect(role.id).not_to be_nil
      end

      it 'does not allow user to create space that already exists' do
        post '/v2/spaces', {
          name: 'v2-space',
          organization_guid: org.guid
        }.to_json

        expect(last_response.status).to eq(201)

        post '/v2/spaces', {
          name: 'v2-space',
          organization_guid: org.guid
        }.to_json

        expect(last_response.status).to eq(400)

        json_body = JSON.parse(last_response.body)
        expect(json_body['error_code']).to eq('CF-SpaceNameTaken')
      end
    end
  end

  describe 'DELETE /v2/spaces/:guid' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }

    let(:worker) { Delayed::Worker.new }

    SPACE_ROLES.each do |role|
      describe 'synchronous deletion' do
        it "deletes the space-#{role}-<space_id> role" do
          post '/v2/spaces', {
            name: 'v2-space',
            organization_guid: org.guid
          }.to_json

          expect(last_response.status).to eq(201)

          json_body = JSON.parse(last_response.body)
          space_id = json_body['metadata']['guid']
          role_name = "space-#{role}-#{space_id}"

          delete "/v2/spaces/#{space_id}"

          expect(last_response.status).to eq(204)

          expect {
            client.get_role(role_name)
          }.to raise_error GRPC::NotFound
        end
      end

      describe 'async deletion' do
        it "deletes the space-#{role}-<space_id> role" do
          post '/v2/spaces', {
            name: 'v2-space',
            organization_guid: org.guid
          }.to_json

          expect(last_response.status).to eq(201)

          json_body = JSON.parse(last_response.body)
          space_id = json_body['metadata']['guid']
          role_name = "space-#{role}-#{space_id}"

          delete "/v2/spaces/#{space_id}?async=true"

          expect(last_response.status).to eq(202)

          succeeded_jobs, failed_jobs = worker.work_off
          expect(succeeded_jobs).to be > 0
          expect(failed_jobs).to equal(0)

          expect {
            client.get_role(role_name)
          }.to raise_error GRPC::NotFound
        end
      end

      it 'alerts the user if the space does not exist' do
        post '/v2/spaces', {
          name: 'v2-space',
          organization_guid: org.guid
        }.to_json

        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        space_id = json_body['metadata']['guid']

        delete "/v2/spaces/#{space_id}"
        expect(last_response.status).to eq(204)

        delete "/v2/spaces/#{space_id}"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'PUT /v2/spaces/:guid/:role/:user_guid' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }
    let(:space) {
      VCAP::CloudController::Space.make(
        organization: org,
      )
    }

    SPACE_ROLES.each do |role|
      describe "PUT /v2/spaces/:guid/#{role}s/:user_guid" do
        let(:role_name) { "space-#{role}-#{space.guid}" }

        before do
          client.create_role(role_name)
        end

        it "assigns the specified user to the space #{role} role" do
          expect(client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)).to be_empty

          put "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          expect(client.has_role?(role_name: role_name, actor_id: assignee.guid, issuer: issuer)).to be(true)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles.length).to be(1)
        end

        it 'does nothing when the user is assigned to the role a second time' do
          expect(client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)).to be_empty

          put "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          put "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          expect(client.has_role?(role_name: role_name, actor_id: assignee.guid, issuer: issuer)).to be(true)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles.length).to be(1)
        end
      end
    end
  end

  describe 'DELETE /v2/spaces/:guid/:role' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) {
      VCAP::CloudController::Space.make(
        organization: org,
      )
    }

    SPACE_ROLES.each do |role|
      describe "DELETE /v2/spaces/:guid/#{role}s" do
        let(:role_name) { "space-#{role}-#{space.guid}" }

        before do
          client.create_role role_name
        end

        it "removes the user from the space #{role} role" do
          client.assign_role(actor_id: assignee.guid, issuer: issuer, role_name: role_name)

          delete "/v2/spaces/#{space.guid}/#{role}s", { 'username' => assignee.username }.to_json
          expect(last_response.status).to eq(200)

          expect(client.has_role?(actor_id: assignee.guid, issuer: issuer, role_name: role_name)).to be(false)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles).to be_empty
        end
      end
    end
  end

  describe 'DELETE /v2/spaces/:guid/:role/:user_guid' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) {
      VCAP::CloudController::Space.make(
        organization: org,
      )
    }

    SPACE_ROLES.each do |role|
      describe "DELETE /v2/spaces/:guid/#{role}s/:user_guid" do
        let(:role_name) { "space-#{role}-#{space.guid}" }

        before do
          client.create_role role_name
        end

        it "removes the user from the space #{role} role" do
          client.assign_role(actor_id: assignee.guid, issuer: issuer, role_name: role_name)

          delete "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)

          expect(client.has_role?(actor_id: assignee.guid, issuer: issuer, role_name: role_name)).to be(false)
          roles = client.list_actor_roles(actor_id: assignee.guid, issuer: issuer)
          expect(roles).to be_empty
        end

        it "does nothing if the user does not have the space #{role} role" do
          delete "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)
        end
      end
    end
  end
end
