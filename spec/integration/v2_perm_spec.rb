require 'spec_helper'
require 'perm'
require 'perm_test_helpers'
require 'securerandom'

# The `perm` symbol is an rspec tag used in RSpec.configure to set an exclusion_filter to avoid showing pending perm tests.
skip_perm_tests = ENV['CF_RUN_PERM_SPECS'] != 'true'
RSpec.describe 'Perm', type: :integration, skip: skip_perm_tests, perm: skip_perm_tests do
  perm_server = nil
  perm_config = {}
  client = nil
  user_id = nil

  ORG_ROLES = [:user, :manager, :auditor, :billing_manager].freeze
  SPACE_ROLES = [:developer, :manager, :auditor].freeze

  include ControllerHelpers

  let(:uaa_target) { 'test.example.com' }
  let(:uaa_origin) { 'test-origin' }

  let(:username) { 'fake-username' }

  let(:issuer) { UAAIssuer::ISSUER }

  if ENV['CF_RUN_PERM_SPECS'] == 'true'
    before(:all) do
      perm_server = CloudFoundry::PermTestHelpers::ServerRunner.new
      perm_server.start

      perm_hostname = perm_server.hostname.clone
      perm_port = perm_server.port.clone
      perm_config = {
        enabled: true,
        hostname: perm_hostname,
        port: perm_port,
        ca_cert_path: perm_server.tls_ca_path,
        timeout_in_milliseconds: 1000,
        query_raise_on_mismatch: true, # Gives us 500s in Querying tests when perm and DB return different answers
      }

      ca_certs = [perm_server.tls_ca.clone]

      client = CloudFoundry::Perm::V1::Client.new(hostname: perm_hostname, port: perm_port, trusted_cas: ca_certs)
    end

    after(:all) do
      perm_server.stop
    end
  end

  before do
    TestConfig.config[:perm] = perm_config

    set_current_user_as_admin(iss: issuer)

    user_id = create_user

    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:origins_for_username).with(username).and_return([uaa_origin])
    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).with([user_id]).and_return({ user_id => username })
    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:id_for_username).with(username).and_return(user_id)
    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:id_for_username).with(username, origin: nil).and_return(user_id)
    allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_return(issuer)
  end

  describe 'POST /v2/organizations' do
    it 'creates the org roles' do
      post '/v2/organizations', { name: SecureRandom.uuid }.to_json

      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org_id = json_body['metadata']['guid']

      ORG_ROLES.each do |role|
        role_name = "org-#{role}-#{org_id}"

        expect(role_exists(client, role_name)).to eq(true)
      end
    end

    it 'does not allow the user to create an org that already exists' do
      body = { name: SecureRandom.uuid }.to_json
      post '/v2/organizations', body

      expect(last_response.status).to eq(201)

      post '/v2/organizations', body

      expect(last_response.status).to eq(400)

      json_body = JSON.parse(last_response.body)
      expect(json_body['error_code']).to eq('CF-OrganizationNameTaken')
    end
  end

  describe 'DELETE /v2/organizations/:guid' do
    let(:worker) { Delayed::Worker.new }

    describe 'when the org does not have spaces' do
      describe 'synchronous deletion' do
        it 'deletes the org roles' do
          post '/v2/organizations', { name: SecureRandom.uuid }.to_json

          expect(last_response.status).to eq(201)

          json_body = JSON.parse(last_response.body)
          org_id = json_body['metadata']['guid']

          delete "/v2/organizations/#{org_id}"

          expect(last_response.status).to eq(204)

          ORG_ROLES.each do |role|
            role_name = "org-#{role}-#{org_id}"

            expect(role_exists(client, role_name)).to eq(false)
          end
        end
      end

      describe 'async deletion' do
        it 'deletes the org roles' do
          post '/v2/organizations', { name: SecureRandom.uuid }.to_json

          expect(last_response.status).to eq(201)

          json_body = JSON.parse(last_response.body)
          org_id = json_body['metadata']['guid']

          delete "/v2/organizations/#{org_id}?async=true"

          expect(last_response.status).to eq(202)

          succeeded_jobs, failed_jobs = worker.work_off
          expect(succeeded_jobs).to be > 0
          expect(failed_jobs).to equal(0)

          ORG_ROLES.each do |role|
            role_name = "org-#{role}-#{org_id}"

            expect(role_exists(client, role_name)).to eq(false)
          end
        end
      end
    end

    describe 'when the org has spaces' do
      describe 'without "recursive" param' do
        it 'alerts the user without deleting any roles' do
          post '/v2/organizations', { name: SecureRandom.uuid }.to_json

          expect(last_response.status).to eq(201)

          json_body = JSON.parse(last_response.body)
          org_id = json_body['metadata']['guid']

          post '/v2/spaces', {
            name: SecureRandom.uuid,
            organization_guid: org_id
          }.to_json

          expect(last_response.status).to eq(201)

          json_body = JSON.parse(last_response.body)

          delete "/v2/organizations/#{org_id}?recursive=false"

          expect(last_response.status).to eq(400)

          ORG_ROLES.each do |role|
            org_role_name = "org-#{role}-#{org_id}"

            expect(role_exists(client, org_role_name)).to eq(true)
          end

          space_id = json_body['metadata']['guid']
          SPACE_ROLES.each do |role|
            space_role_name = "space-#{role}-#{space_id}"

            expect(role_exists(client, space_role_name)).to eq(true)
          end
        end
      end

      describe 'with "recursive" param' do
        describe 'synchronous deletion' do
          it 'deletes the roles recursively' do
            post '/v2/organizations', { name: SecureRandom.uuid }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)
            org_id = json_body['metadata']['guid']

            post '/v2/spaces', {
              name: SecureRandom.uuid,
              organization_guid: org_id
            }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)

            delete "/v2/organizations/#{org_id}?recursive=true"

            expect(last_response.status).to eq(204)

            ORG_ROLES.each do |role|
              org_role_name = "org-#{role}-#{org_id}"

              expect(role_exists(client, org_role_name)).to eq(false)
            end

            space_id = json_body['metadata']['guid']
            SPACE_ROLES.each do |role|
              space_role_name = "space-#{role}-#{space_id}"
              expect(role_exists(client, space_role_name)).to eq(false)
            end
          end
        end

        describe 'async deletion' do
          it 'deletes the roles recursively' do
            post '/v2/organizations', { name: SecureRandom.uuid }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)
            org_id = json_body['metadata']['guid']

            post '/v2/spaces', {
              name: SecureRandom.uuid,
              organization_guid: org_id
            }.to_json

            expect(last_response.status).to eq(201)

            json_body = JSON.parse(last_response.body)

            delete "/v2/organizations/#{org_id}?recursive=true&async=true"

            expect(last_response.status).to eq(202)

            succeeded_jobs, failed_jobs = worker.work_off
            expect(succeeded_jobs).to be > 0
            expect(failed_jobs).to equal(0)

            ORG_ROLES.each do |role|
              org_role_name = "org-#{role}-#{org_id}"

              expect(role_exists(client, org_role_name)).to eq(false)
            end

            space_id = json_body['metadata']['guid']
            SPACE_ROLES.each do |role|
              space_role_name = "space-#{role}-#{space_id}"
              expect(role_exists(client, space_role_name)).to eq(false)
            end
          end
        end
      end

      it 'alerts the user if the org does not exist' do
        post '/v2/organizations', { name: SecureRandom.uuid }.to_json
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
    ORG_ROLES.each do |role|
      describe "PUT /v2/organizations/:guid/#{role}s/:user_guid" do
        org_id = nil

        let(:role_name) { "org-#{role}-#{org.guid}" }

        before do
          post '/v2/organizations', { name: SecureRandom.uuid }.to_json
          expect(last_response.status).to eq(201)

          json_body = JSON.parse(last_response.body)
          org_id = json_body['metadata']['guid']
        end

        it "assigns the specified user to the org #{role} role" do
          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "org.#{role}", resource: org_id)
          expect(has_permission).to eq(false)

          put "/v2/organizations/#{org_id}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "org.#{role}", resource: org_id)
          expect(has_permission).to eq(true)
        end

        it 'does nothing when the user is assigned to the role a second time' do
          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "org.#{role}", resource: org_id)
          expect(has_permission).to eq(false)

          put "/v2/organizations/#{org_id}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(201)

          put "/v2/organizations/#{org_id}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "org.#{role}", resource: org_id)
          expect(has_permission).to eq(true)
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
          client.create_role(role_name: role_name)
        end

        it "removes the user from the org #{role} role" do
          client.assign_role(role_name: role_name, actor_id: user_id, namespace: issuer)

          delete "/v2/organizations/#{org.guid}/#{role}s", { 'username' => username }.to_json
          expect(last_response.status).to eq(204)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: org.guid)
          expect(has_permission).to eq(false)
        end

        it "does nothing if the user does not have the org #{role} role" do
          delete "/v2/organizations/#{org.guid}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  describe 'DELETE /v2/organizations/:guid/users?recursive=true' do
    org1_id = nil
    org2_id = nil
    org1_space_id = nil
    org2_space_id = nil

    before do
      post '/v2/organizations', { name: SecureRandom.uuid }.to_json
      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org1_id = json_body['metadata']['guid']

      post '/v2/organizations', { name: SecureRandom.uuid }.to_json
      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org2_id = json_body['metadata']['guid']

      put "/v2/organizations/#{org1_id}/users/#{user_id}"
      expect(last_response.status).to eq(201)

      put "/v2/organizations/#{org2_id}/users/#{user_id}"
      expect(last_response.status).to eq(201)

      post '/v2/spaces', {
        name: SecureRandom.uuid,
        organization_guid: org1_id
      }.to_json

      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org1_space_id = json_body['metadata']['guid']

      post '/v2/spaces', {
        name: SecureRandom.uuid,
        organization_guid: org2_id
      }.to_json

      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org2_space_id = json_body['metadata']['guid']

      SPACE_ROLES.each do |role|
        put "/v2/spaces/#{org1_space_id}/#{role}s/#{user_id}"
        expect(last_response.status).to eq(201)

        put "/v2/spaces/#{org2_space_id}/#{role}s/#{user_id}"
        expect(last_response.status).to eq(201)
      end
    end

    it 'removes the user from all org and space roles for that org and no other' do
      delete "/v2/organizations/#{org1_id}/users?recursive=true", { 'username' => username }.to_json
      expect(last_response.status).to eq(204)

      has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: 'org.user', resource: org1_id)
      expect(has_permission).to eq(false)

      has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: 'org.user', resource: org2_id)
      expect(has_permission).to eq(true)

      SPACE_ROLES.each do |role|
        has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: org1_space_id)
        expect(has_permission).to eq(false)

        has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: org2_space_id)
        expect(has_permission).to eq(true)
      end
    end
  end

  describe 'DELETE /v2/organizations/:guid/:role/:user_guid' do
    let(:org) { VCAP::CloudController::Organization.make }

    ORG_ROLES.each do |role|
      describe "DELETE /v2/organizations/:guid/#{role}s/:user_guid" do
        let(:role_name) { "org-#{role}-#{org.guid}" }

        before do
          client.create_role(role_name: role_name)
        end

        it "removes the user from the org #{role} role" do
          client.assign_role(role_name: role_name, actor_id: user_id, namespace: issuer)

          delete "/v2/organizations/#{org.guid}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(204)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "org.#{role}", resource: org.guid)
          expect(has_permission).to eq(false)
        end

        it "does nothing if the user does not have the org #{role} role" do
          delete "/v2/organizations/#{org.guid}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  describe 'POST /v2/spaces' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [user_id]) }

    it 'creates the space roles' do
      post '/v2/spaces', {
        name: SecureRandom.uuid,
        organization_guid: org.guid
      }.to_json

      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      space_id = json_body['metadata']['guid']
      SPACE_ROLES.each do |role|
        role_name = "space-#{role}-#{space_id}"

        expect(role_exists(client, role_name)).to eq(true)
      end
    end

    it 'does not allow user to create space that already exists' do
      space_name = SecureRandom.uuid

      post '/v2/spaces', {
        name: space_name,
        organization_guid: org.guid
      }.to_json

      expect(last_response.status).to eq(201)

      post '/v2/spaces', {
        name: space_name,
        organization_guid: org.guid
      }.to_json

      expect(last_response.status).to eq(400)

      json_body = JSON.parse(last_response.body)
      expect(json_body['error_code']).to eq('CF-SpaceNameTaken')
    end
  end

  describe 'DELETE /v2/spaces/:guid' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [user_id]) }

    let(:worker) { Delayed::Worker.new }

    describe 'synchronous deletion' do
      it 'deletes the space roles' do
        post '/v2/spaces', {
          name: SecureRandom.uuid,
          organization_guid: org.guid
        }.to_json

        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        space_id = json_body['metadata']['guid']

        delete "/v2/spaces/#{space_id}"

        expect(last_response.status).to eq(204)

        SPACE_ROLES.each do |role|
          role_name = "space-#{role}-#{space_id}"

          expect(role_exists(client, role_name)).to eq(false)
        end
      end
    end

    describe 'async deletion' do
      it 'deletes the space roles' do
        post '/v2/spaces', {
          name: SecureRandom.uuid,
          organization_guid: org.guid
        }.to_json

        expect(last_response.status).to eq(201)

        json_body = JSON.parse(last_response.body)
        space_id = json_body['metadata']['guid']

        delete "/v2/spaces/#{space_id}?async=true"

        expect(last_response.status).to eq(202)

        succeeded_jobs, failed_jobs = worker.work_off
        expect(succeeded_jobs).to be > 0
        expect(failed_jobs).to equal(0)

        SPACE_ROLES.each do |role|
          role_name = "space-#{role}-#{space_id}"
          expect(role_exists(client, role_name)).to eq(false)
        end
      end
    end

    it 'alerts the user if the space does not exist' do
      post '/v2/spaces', {
        name: SecureRandom.uuid,
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

  describe 'PUT /v2/spaces/:guid/:role/:user_guid' do
    space_id = nil
    before do
      post '/v2/organizations', { name: SecureRandom.uuid }.to_json

      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org_id = json_body['metadata']['guid']

      post '/v2/spaces', {
        name: SecureRandom.uuid,
        organization_guid: org_id
      }.to_json

      expect(last_response.status).to eq(201)
      json_body = JSON.parse(last_response.body)
      space_id = json_body['metadata']['guid']

      put "/v2/organizations/#{org_id}/users/#{user_id}"
      expect(last_response.status).to eq(201)
    end

    SPACE_ROLES.each do |role|
      describe "PUT /v2/spaces/:guid/#{role}s/:user_guid" do
        it "assigns the specified user to the space #{role} role" do
          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: space_id)
          expect(has_permission).to eq(false)

          put "/v2/spaces/#{space_id}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: space_id)
          expect(has_permission).to eq(true)
        end

        it 'does nothing when the user is assigned to the role a second time' do
          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: space_id)
          expect(has_permission).to eq(false)

          put "/v2/spaces/#{space_id}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(201)

          put "/v2/spaces/#{space_id}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: space_id)
          expect(has_permission).to eq(true)
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
          client.create_role(role_name: role_name)
        end

        it "removes the user from the space #{role} role" do
          client.assign_role(actor_id: user_id, namespace: issuer, role_name: role_name)

          delete "/v2/spaces/#{space.guid}/#{role}s", { 'username' => username }.to_json
          expect(last_response.status).to eq(200)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: space.guid)
          expect(has_permission).to eq(false)
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
          client.create_role(role_name: role_name)
        end

        it "removes the user from the space #{role} role" do
          client.assign_role(actor_id: user_id, namespace: issuer, role_name: role_name)

          delete "/v2/spaces/#{space.guid}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(204)

          has_permission = client.has_permission?(actor_id: user_id, namespace: issuer, action: "space.#{role}", resource: space.guid)
          expect(has_permission).to eq(false)
        end

        it "does nothing if the user does not have the space #{role} role" do
          delete "/v2/spaces/#{space.guid}/#{role}s/#{user_id}"
          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  def create_user
    body = {
      guid: SecureRandom.uuid
    }.to_json

    post('/v2/users', body)
    expect(last_response.status).to eq(201)

    json_body = JSON.parse(last_response.body)
    json_body['metadata']['guid']
  end

  def create_org
    body = {
      name: SecureRandom.uuid
    }.to_json

    post '/v2/organizations', body

    expect(last_response.status).to eq(201)

    response.json_body['metadata']['guid']
  end

  def create_space(org_guid)
    body = {
      name: SecureRandom.uuid,
      relationships: {
        organization: {
          data: {
            guid: org_guid
          }
        }
      }
    }.to_json

    post "/v2/organizations/#{org_guid}/spaces", body

    expect(last_response.status).to eq(201)

    response.json_body['metadata']['guid']
  end

  def role_exists(client, role_name)
    begin
      client.create_role(role_name: role_name)
    rescue CloudFoundry::Perm::V1::Errors::AlreadyExists
      return true
    end

    client.delete_role(role_name)
    false
  end
end
