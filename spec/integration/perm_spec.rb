require 'spec_helper'
require 'perm'
require 'perm_test_helpers'
require 'rails_helper'
require 'securerandom'

# The `perm` symbol is an rspec tag used in RSpec.configure to set an exclusion_filter to avoid showing pending perm tests.
skip_perm_tests = ENV['CF_RUN_PERM_SPECS'] != 'true'
RSpec.describe 'Perm', type: :integration, skip: skip_perm_tests, perm: skip_perm_tests do
  perm_server = nil
  perm_config = {}
  client = nil

  ORG_ROLES = [:user, :manager, :auditor, :billing_manager].freeze
  SPACE_ROLES = [:developer, :manager, :auditor].freeze

  include ControllerHelpers

  let(:assignee) { VCAP::CloudController::User.make(username: 'not-really-a-person') }
  let(:uaa_target) { 'test.example.com' }
  let(:uaa_origin) { 'test-origin' }

  let(:issuer) { UAAIssuer::ISSUER }

  def http_headers(token)
    {
      'authorization' => "bearer #{token}",
      'accept' => 'application/json',
      'content-type' => 'application/json'
    }
  end

  def admin_headers
    http_headers(admin_token)
  end

  if ENV['CF_RUN_PERM_SPECS'] == 'true'
    before(:all) do
      perm_server = CloudFoundry::PermTestHelpers::ServerRunner.new
      perm_server.start

      perm_hostname = perm_server.hostname.clone
      perm_port = perm_server.port.clone
      perm_config = {
        enabled: true,
        query_enabled: true,
        hostname: perm_hostname,
        port: perm_port,
        ca_cert_path: perm_server.tls_ca_path,
        timeout_in_milliseconds: 1000,
        query_raise_on_mismatch: true, # Gives us 500s in Querying tests when perm and DB return different answers
      }

      ca_certs = [perm_server.tls_ca.clone]

      client = CloudFoundry::Perm::V1::Client.new(hostname: perm_hostname, port: perm_port, trusted_cas: ca_certs)

      config = YAML.load_file('config/cloud_controller.yml')
      config[:perm] = perm_config
      config_file = Tempfile.new('perm_config')
      config_file.write(config.to_json)
      config_file.flush

      start_cc({ config: config_file.path })

      config_file.unlink
      config_file.close
    end

    after(:all) do
      stop_cc

      perm_server.stop
    end
  end

  before do
    TestConfig.config[:perm] = perm_config

    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:origins_for_username).with(assignee.username).and_return([uaa_origin])
    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:usernames_for_ids).with([assignee.guid]).and_return({ assignee.guid => assignee.username })
    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:id_for_username).with(assignee.username).and_return(assignee.guid)
    allow_any_instance_of(VCAP::CloudController::UaaClient).to receive(:id_for_username).with(assignee.username, origin: nil).and_return(assignee.guid)
    allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_return(issuer)

    set_current_user_as_admin(iss: issuer)
  end

  describe 'POST /v3/organizations' do
    it 'creates the org roles in perm' do
      body = { name: SecureRandom.uuid }.to_json
      response = make_post_request('/v3/organizations', body, admin_headers)

      expect(response.code).to eq('201')

      json_body = response.json_body
      org_id = json_body['guid']

      ORG_ROLES.each do |role|
        role_name = "org-#{role}-#{org_id}"

        expect(role_exists(client, role_name)).to eq(true)
      end
    end

    it 'does not allow the user to create an org that already exists' do
      body = { name: SecureRandom.uuid }.to_json
      response = make_post_request('/v3/organizations', body, admin_headers)

      expect(response.code).to eq('201')

      response = make_post_request('/v3/organizations', body, admin_headers)

      expect(response.code).to eq('422')
    end
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
          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "org.#{role}", resource: org_id)
          expect(has_permission).to eq(false)

          put "/v2/organizations/#{org_id}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "org.#{role}", resource: org_id)
          expect(has_permission).to eq(true)
        end

        it 'does nothing when the user is assigned to the role a second time' do
          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "org.#{role}", resource: org_id)
          expect(has_permission).to eq(false)

          put "/v2/organizations/#{org_id}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          put "/v2/organizations/#{org_id}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "org.#{role}", resource: org_id)
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
          client.assign_role(role_name: role_name, actor_id: assignee.guid, namespace: issuer)

          delete "/v2/organizations/#{org.guid}/#{role}s", { 'username' => assignee.username }.to_json
          expect(last_response.status).to eq(204)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: org.guid)
          expect(has_permission).to eq(false)
        end

        it "does nothing if the user does not have the org #{role} role" do
          delete "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
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
    # let!(:org1) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }
    # let!(:org2) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }
    # let!(:org1_space) { VCAP::CloudController::Space.make(organization: org1) }
    # let!(:org2_space) { VCAP::CloudController::Space.make(organization: org2) }

    before do
      post '/v2/organizations', { name: SecureRandom.uuid }.to_json
      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org1_id = json_body['metadata']['guid']

      post '/v2/organizations', { name: SecureRandom.uuid }.to_json
      expect(last_response.status).to eq(201)

      json_body = JSON.parse(last_response.body)
      org2_id = json_body['metadata']['guid']

      put "/v2/organizations/#{org1_id}/users/#{assignee.guid}"
      expect(last_response.status).to eq(201)

      put "/v2/organizations/#{org2_id}/users/#{assignee.guid}"
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
        put "/v2/spaces/#{org1_space_id}/#{role}s/#{assignee.guid}"
        expect(last_response.status).to eq(201)

        put "/v2/spaces/#{org2_space_id}/#{role}s/#{assignee.guid}"
        expect(last_response.status).to eq(201)
      end
    end

    it 'removes the user from all org and space roles for that org and no other' do
      delete "/v2/organizations/#{org1_id}/users?recursive=true", { 'username' => assignee.username }.to_json
      expect(last_response.status).to eq(204)

      has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: 'org.user', resource: org1_id)
      expect(has_permission).to eq(false)

      has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: 'org.user', resource: org2_id)
      expect(has_permission).to eq(true)

      SPACE_ROLES.each do |role|
        has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: org1_space_id)
        expect(has_permission).to eq(false)

        has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: org2_space_id)
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
          client.assign_role(role_name: role_name, actor_id: assignee.guid, namespace: issuer)

          delete "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "org.#{role}", resource: org.guid)
          expect(has_permission).to eq(false)
        end

        it "does nothing if the user does not have the org #{role} role" do
          delete "/v2/organizations/#{org.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  describe 'POST /v3/spaces' do
    org_guid = nil

    before do
      org = org_with_default_quota(admin_headers)
      org_guid = org.json_body['metadata']['guid']
    end

    it 'creates the space roles' do
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

      response = make_post_request('/v3/spaces', body, admin_headers)
      expect(response.code).to eq('201')

      json_body = response.json_body
      space_id = json_body['guid']

      SPACE_ROLES.each do |role|
        role_name = "space-#{role}-#{space_id}"
        expect(role_exists(client, role_name)).to eq(true)
      end
    end

    it 'does not allow user to create space that already exists' do
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

      response = make_post_request('/v3/spaces', body, admin_headers)

      expect(response.code).to eq('201')

      response = make_post_request('/v3/spaces', body, admin_headers)

      expect(response.code).to eq('422')
    end
  end

  describe 'POST /v2/spaces' do
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }

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
    let(:org) { VCAP::CloudController::Organization.make(user_guids: [assignee.guid]) }

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

      put "/v2/organizations/#{org_id}/users/#{assignee.guid}"
      expect(last_response.status).to eq(201)
    end

    SPACE_ROLES.each do |role|
      describe "PUT /v2/spaces/:guid/#{role}s/:user_guid" do
        it "assigns the specified user to the space #{role} role" do
          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: space_id)
          expect(has_permission).to eq(false)

          put "/v2/spaces/#{space_id}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: space_id)
          expect(has_permission).to eq(true)
        end

        it 'does nothing when the user is assigned to the role a second time' do
          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: space_id)
          expect(has_permission).to eq(false)

          put "/v2/spaces/#{space_id}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          put "/v2/spaces/#{space_id}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(201)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: space_id)
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
          client.assign_role(actor_id: assignee.guid, namespace: issuer, role_name: role_name)

          delete "/v2/spaces/#{space.guid}/#{role}s", { 'username' => assignee.username }.to_json
          expect(last_response.status).to eq(200)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: space.guid)
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
          client.assign_role(actor_id: assignee.guid, namespace: issuer, role_name: role_name)

          delete "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)

          has_permission = client.has_permission?(actor_id: assignee.guid, namespace: issuer, action: "space.#{role}", resource: space.guid)
          expect(has_permission).to eq(false)
        end

        it "does nothing if the user does not have the space #{role} role" do
          delete "/v2/spaces/#{space.guid}/#{role}s/#{assignee.guid}"
          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  RSpec.shared_examples 'org reader' do
    it 'can read from org (can_read_from_org?)' do
      opts = {
        user_id: user.guid,
        scope: %w(cloud_controller.read cloud_controller.write),
      }
      response = make_get_request("/v3/organizations/#{org_guid}", http_headers(auth_token(opts)))
      expect(response.code).to eq('200')

      expect(response.json_body['guid']).to eq(org_guid)
    end

    it 'can read an isolation segment entitled to that org (can_read_from_isolation_segment?)' do
      body = {
        name: SecureRandom.uuid
      }.to_json

      response = make_post_request('/v3/isolation_segments', body, admin_headers)
      expect(response.code).to eq('201')
      isolation_segment_guid = response.json_body['guid']

      body = {
        data:
          [
            { guid: org_guid }
          ]
      }.to_json

      response = make_post_request("/v3/isolation_segments/#{isolation_segment_guid}/relationships/organizations", body, admin_headers)
      expect(response.code).to eq('200')

      opts = {
        user_id: user.guid,
        scope: %w(cloud_controller.read cloud_controller.write),
      }
      response = make_get_request("/v3/isolation_segments/#{isolation_segment_guid}", http_headers(auth_token(opts)))
      expect(response.code).to eq('200')

      expect(response.json_body['guid']).to eq(isolation_segment_guid)
    end
  end

  RSpec.shared_examples 'org writer' do
    it 'can create a space in the org (can_write_to_org?)' do
      opts = {
        user_id: user.guid,
        scope: %w(cloud_controller.read cloud_controller.write),
      }

      space_name = SecureRandom.uuid
      body = {
        name: space_name,
        relationships: {
          organization: {
            data: {
              guid: org_guid
            }
          }
        }
      }.to_json

      response = make_post_request('/v3/spaces', body, http_headers(auth_token(opts)))
      expect(response.code).to eq('201')

      expect(response.json_body['name']).to eq(space_name)
    end
  end

  RSpec.shared_examples 'space reader' do
    it 'can read from space (can_read_from_space?)' do
      opts = {
        user_id: user.guid,
        scope: %w(cloud_controller.read cloud_controller.write),
      }
      response = make_get_request("/v3/spaces/#{space_guid}", http_headers(auth_token(opts)))
      expect(response.code).to eq('200')

      expect(response.json_body['guid']).to eq(space_guid)
    end

    it 'can read an isolation segment entitled to that space (can_read_from_isolation_segment?)' do
      body = {
        name: SecureRandom.uuid
      }.to_json

      response = make_post_request('/v3/isolation_segments', body, admin_headers)
      expect(response.code).to eq('201')
      isolation_segment_guid = response.json_body['guid']

      body = {
        data:
          [
            { guid: org_guid }
          ]
      }.to_json

      response = make_post_request("/v3/isolation_segments/#{isolation_segment_guid}/relationships/organizations", body, admin_headers)
      expect(response.code).to eq('200')

      body = {
        data: {
          guid: isolation_segment_guid
        }
      }.to_json

      response = make_patch_request("/v3/spaces/#{space_guid}/relationships/isolation_segment", body, admin_headers)
      expect(response.code).to eq('200')

      opts = {
        user_id: user.guid,
        scope: %w(cloud_controller.read cloud_controller.write),
      }
      response = make_get_request("/v3/isolation_segments/#{isolation_segment_guid}", http_headers(auth_token(opts)))
      expect(response.code).to eq('200')

      expect(response.json_body['guid']).to eq(isolation_segment_guid)
    end
  end

  RSpec.shared_examples 'space writer' do
    it 'can create an app in the space (can_write_to_space?)' do
      opts = {
        user_id: user.guid,
        scope: %w(cloud_controller.read cloud_controller.write),
      }

      app_name = SecureRandom.uuid
      body = {
        name: app_name,
        relationships: {
          space: {
            data: {
              guid: space_guid
            }
          }
        }
      }.to_json

      response = make_post_request('/v3/apps', body, http_headers(auth_token(opts)))
      expect(response.code).to eq('201')

      expect(response.json_body['name']).to eq(app_name)
    end
  end

  describe 'org manager' do
    setup = ->() {
      let(:user) { VCAP::CloudController::User.make }
      let(:org_guid) { create_org }
      let(:space_guid) { create_space(org_guid) }

      before do
        set_current_user_as_admin(iss: issuer)

        make_org_user(user, org_guid)

        response = make_put_request("/v2/organizations/#{org_guid}/managers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')

        set_current_user(user, iss: issuer)
      end
    }

    it_behaves_like 'org reader', &setup
    it_behaves_like 'org writer', &setup
    it_behaves_like 'space reader', &setup
  end

  describe 'org auditor' do
    setup = ->() {
      let(:user) { VCAP::CloudController::User.make }
      let(:org_guid) { create_org }
      let(:space_guid) { create_space(org_guid) }

      before do
        set_current_user_as_admin(iss: issuer)

        make_org_user(user, org_guid)

        response = make_put_request("/v2/organizations/#{org_guid}/auditors/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')

        set_current_user(user, iss: issuer)
      end
    }

    it_behaves_like 'org reader', &setup
  end

  describe 'org billing manager' do
    setup = ->() {
      let(:user) { VCAP::CloudController::User.make }
      let(:org_guid) { create_org }
      let(:space_guid) { create_space(org_guid) }

      before do
        set_current_user_as_admin(iss: issuer)

        make_org_user(user, org_guid)

        response = make_put_request("/v2/organizations/#{org_guid}/billing_managers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')

        set_current_user(user, iss: issuer)
      end
    }

    it_behaves_like 'org reader', &setup
  end

  describe 'org user' do
    setup = ->() {
      let(:user) { VCAP::CloudController::User.make }
      let(:org_guid) { create_org }
      let(:space_guid) { create_space(org_guid) }

      before do
        set_current_user_as_admin(iss: issuer)

        make_org_user(user, org_guid)
        set_current_user(user, iss: issuer)
      end
    }

    it_behaves_like 'org reader', &setup
  end

  describe 'space developer' do
    setup = ->() {
      let(:user) { VCAP::CloudController::User.make }
      let(:org_guid) { create_org }
      let(:space_guid) { create_space(org_guid) }

      before do
        set_current_user_as_admin(iss: issuer)

        make_org_user(user, org_guid)

        response = make_put_request("/v2/spaces/#{space_guid}/developers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')

        set_current_user(user, iss: issuer)
      end
    }

    it_behaves_like 'space reader', &setup
    it_behaves_like 'space writer', &setup
  end

  describe 'space manager' do
    setup = ->() {
      let(:user) { VCAP::CloudController::User.make }
      let(:org_guid) { create_org }
      let(:space_guid) { create_space(org_guid) }

      before do
        set_current_user_as_admin(iss: issuer)

        make_org_user(user, org_guid)

        response = make_put_request("/v2/spaces/#{space_guid}/managers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')

        set_current_user(user, iss: issuer)
      end
    }

    it_behaves_like 'space reader', &setup
  end

  describe 'space auditor' do
    setup = ->() {
      let(:user) { VCAP::CloudController::User.make }
      let(:org_guid) { create_org }
      let(:space_guid) { create_space(org_guid) }

      before do
        set_current_user_as_admin(iss: issuer)

        make_org_user(user, org_guid)

        response = make_put_request("/v2/spaces/#{space_guid}/auditors/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')

        set_current_user(user, iss: issuer)
      end
    }

    it_behaves_like 'space reader', &setup
  end

  def create_org
    body = {
      name: SecureRandom.uuid
    }.to_json

    response = make_post_request('/v3/organizations', body, admin_headers)
    expect(response.code).to eq('201')

    response.json_body['guid']
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

    response = make_post_request('/v3/spaces', body, admin_headers)
    expect(response.code).to eq('201')

    response.json_body['guid']
  end

  def make_org_user(user, org_guid)
    response = make_put_request("/v2/organizations/#{org_guid}/users/#{user.guid}", {}.to_json, admin_headers)
    expect(response.code).to eq('201')
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
