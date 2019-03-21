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

  let(:org_roles) { [:user, :manager, :auditor, :billing_manager].freeze }
  let(:space_roles) { [:developer, :manager, :auditor].freeze }

  let(:uaa_target) { 'test.example.com' }
  let(:uaa_origin) { 'test-origin' }
  let(:issuer) { UAAIssuer::ISSUER }
  let(:user_guid) { create_user }

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

  def user_headers
    http_headers(user_auth_token(user_guid))
  end

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

      config = VCAP::CloudController::YAMLConfig.safe_load_file('config/cloud_controller.yml')
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
  end

  describe 'GET /v3/organizations' do
    let(:org_guid1) { create_org }
    let(:org_guid2) { create_org }
    let(:org_guid3) { create_org }
    let!(:org_guids) { [org_guid1, org_guid2, org_guid3] }

    it 'returns an empty list when the user is a member of no organizations' do
      response = make_get_request('/v3/organizations', user_headers)
      expect(response.code).to eq('200')

      actual_org_guids = response.json_body['resources'].map { |resource| resource['guid'] }
      expect(actual_org_guids).to have(0).items
    end

    [:admin, :admin_read_only, :global_auditor].each do |role|
      it "returns all the organizations when the user is a(n) #{role}" do
        opts = {}
        opts[role] = true

        expected_org_guids = org_guids

        # There may be > 50 results (default page size) due to pollution
        response = make_get_request('/v3/organizations?per_page=5000', http_headers(user_token(VCAP::CloudController::User.make, opts)))
        expect(response.code).to eq('200')

        actual_org_guids = response.json_body['resources'].map { |resource| resource['guid'] }

        expected_org_guids.each do |expected_org_guid|
          expect(actual_org_guids).to include(expected_org_guid)
        end
      end
    end

    [:user, :manager, :billing_manager, :auditor].each do |role|
      it "returns only the organizations that user has access to as a #{role}" do
        expected_org_guids = [org_guid1, org_guid2]

        expected_org_guids.each do |org_guid|
          response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
          expect(response.code).to eq('201')
        end

        response = make_get_request('/v3/organizations', user_headers)
        expect(response.code).to eq('200')

        actual_org_guids = response.json_body['resources'].map { |resource| resource['guid'] }
        expect(actual_org_guids).to have(expected_org_guids.size).items
        expected_org_guids.each do |expected_org_guid|
          expect(actual_org_guids).to include(expected_org_guid)
        end
      end
    end
  end

  describe 'POST /v3/organizations' do
    it 'creates the org roles in perm' do
      body = { name: SecureRandom.uuid }.to_json
      response = make_post_request('/v3/organizations', body, admin_headers)

      expect(response.code).to eq('201')

      json_body = response.json_body
      org_guid = json_body['guid']

      org_roles.each do |role|
        role_name = "org-#{role}-#{org_guid}"

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

  describe 'GET /v3/organizations/:org_guid' do
    let(:org_guid) { create_org }

    it 'fails when the user is not associated with the org' do
      response = make_get_request("/v3/organizations/#{org_guid}", user_headers)
      expect(response.code).to eq('404')
    end

    [:user, :manager, :billing_manager, :auditor].each do |role|
      it "succeeds when the user is a(n) #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request("/v3/organizations/#{org_guid}", user_headers)
        expect(response.code).to eq('200')

        expect(response.json_body['guid']).to eq(org_guid)
      end
    end
  end

  describe 'GET /v3/isolation_segments/:isolation_segment_guid' do
    let(:org_guid) { create_org }

    it 'fails when the user is not associated with any organizations associated with the isolation segment' do
      body = {
        name: SecureRandom.uuid
      }.to_json

      response = make_post_request('/v3/isolation_segments', body, admin_headers)
      expect(response.code).to eq('201')

      isolation_segment_guid = response.json_body['guid']

      response = make_get_request("/v3/isolation_segments/#{isolation_segment_guid}", user_headers)
      expect(response.code).to eq('404')
    end

    it 'succeeds when the user has a role in an organization associated with the isolation segment' do
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

      [:user, :manager, :billing_manager, :auditor].each do |role|
        response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request("/v3/isolation_segments/#{isolation_segment_guid}", user_headers)
        expect(response.code).to eq('200')

        expect(response.json_body['guid']).to eq(isolation_segment_guid)
      end
    end
  end

  describe 'GET /v3/spaces' do
    let(:org_guid1) { create_org }
    let(:org_guid2) { create_org }
    let(:org_guid3) { create_org }
    let(:org_guids) { [org_guid1, org_guid2, org_guid3] }
    let(:space_guid1) { create_space(org_guid1) }
    let(:space_guid2) { create_space(org_guid1) }
    let(:space_guid3) { create_space(org_guid2) }
    let!(:space_guids) { [space_guid1, space_guid2, space_guid3] }

    it 'returns an empty list when the user is a member of no spaces or orgs' do
      response = make_get_request('/v3/spaces', user_headers)
      expect(response.code).to eq('200')

      actual_space_guids = response.json_body['resources'].map { |resource| resource['guid'] }
      expect(actual_space_guids).to have(0).items
    end

    [:admin, :admin_read_only, :global_auditor].each do |role|
      it "returns all the spaces when the user is a(n) #{role}" do
        opts = {}
        opts[role] = true

        expected_space_guids = space_guids

        # There may be > 50 results (default page size) due to pollution
        response = make_get_request('/v3/spaces?per_page=5000', http_headers(user_token(VCAP::CloudController::User.make, opts)))
        expect(response.code).to eq('200')

        actual_space_guids = response.json_body['resources'].map { |resource| resource['guid'] }

        expected_space_guids.each do |expected_space_guid|
          expect(actual_space_guids).to include(expected_space_guid)
        end
      end
    end

    [:manager].each do |role|
      it "returns all the spaces where the user is an organization #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid1}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request('/v3/spaces', user_headers)
        expect(response.code).to eq('200')

        actual_space_guids = response.json_body['resources'].map { |resource| resource['guid'] }
        expected_space_guids = [space_guid1, space_guid2]

        expected_space_guids.each do |expected_space_guid|
          expect(actual_space_guids).to include(expected_space_guid)
        end
      end
    end

    [:user, :billing_manager, :auditor].each do |role|
      it "does not return spaces where the user is an organization #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid1}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request('/v3/spaces', user_headers)
        expect(response.code).to eq('200')

        actual_space_guids = response.json_body['resources'].map { |resource| resource['guid'] }

        expect(actual_space_guids).to have(0).items
      end
    end

    [:developer, :manager, :auditor].each do |role|
      it "returns spaces where the user is a space #{role}" do
        org_guids.each do |org_guid|
          response = make_put_request("/v2/organizations/#{org_guid}/users/#{user_guid}", '', admin_headers)
          expect(response.code).to eq('201')
        end

        expected_space_guids = [space_guid1, space_guid3]

        expected_space_guids.each do |space_guid|
          response = make_put_request("/v2/spaces/#{space_guid}/#{role}s/#{user_guid}", '', admin_headers)
          expect(response.code).to eq('201')
        end

        response = make_get_request('/v3/spaces', user_headers)
        expect(response.code).to eq('200')

        actual_space_guids = response.json_body['resources'].map { |resource| resource['guid'] }
        expect(actual_space_guids).to have(expected_space_guids.size).items
        expected_space_guids.each do |expected_space_guid|
          expect(actual_space_guids).to include(expected_space_guid)
        end
      end
    end
  end

  describe 'POST /v3/spaces' do
    let(:org_guid) { create_org }
    let(:body) do
      {
        name: SecureRandom.uuid,
        relationships: {
          organization: {
            data: {
              guid: org_guid
            }
          }
        }
      }.to_json
    end

    it 'creates the space roles' do
      response = make_post_request('/v3/spaces', body, admin_headers)

      expect(response.code).to eq('201')

      space_guid = response.json_body['guid']

      space_roles.each do |role|
        role_name = "space-#{role}-#{space_guid}"
        expect(role_exists(client, role_name)).to eq(true)
      end
    end

    it 'does not allow user to create space that already exists' do
      response = make_post_request('/v3/spaces', body, admin_headers)

      expect(response.code).to eq('201')

      response = make_post_request('/v3/spaces', body, admin_headers)

      expect(response.code).to eq('422')
    end

    it 'fails if the user is not associated with the organization' do
      response = make_post_request('/v3/spaces', body, user_headers)

      expect(response.code).to eq('422')
    end

    [:user, :billing_manager, :auditor].each do |role|
      it "fails if the user is a(n) #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_post_request('/v3/spaces', body, user_headers)
        expect(response.code).to eq('403')
      end
    end

    [:manager].each do |role|
      it "succeeds if the user is a(n) #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_post_request('/v3/spaces', body, user_headers)
        expect(response.code).to eq('201')
      end
    end
  end

  describe 'GET /v3/spaces/:space_guid' do
    let(:org_guid) { create_org }
    let(:space_guid) { create_space(org_guid) }

    it 'fails when the user is not associated with the space' do
      response = make_get_request("/v3/spaces/#{space_guid}", user_headers)
      expect(response.code).to eq('404')
    end

    [:manager].each do |role|
      it "succeeds when the user is a organization #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request("/v3/spaces/#{space_guid}", user_headers)
        expect(response.code).to eq('200')

        expect(response.json_body['guid']).to eq(space_guid)
      end
    end

    [:user, :billing_manager, :auditor].each do |role|
      it "fails when the user is an organization #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request("/v3/spaces/#{space_guid}", user_headers)
        expect(response.code).to eq('404')
      end
    end

    [:manager, :developer, :auditor].each do |role|
      it "succeeds when the user is a space #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/users/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_put_request("/v2/spaces/#{space_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request("/v3/spaces/#{space_guid}", user_headers)
        expect(response.code).to eq('200')

        expect(response.json_body['guid']).to eq(space_guid)
      end
    end
  end

  describe 'GET /v3/apps' do
    let(:org_guid1) { create_org }
    let(:org_guid2) { create_org }
    let(:org_guid3) { create_org }
    let(:org_guids) { [org_guid1, org_guid2, org_guid3] }
    let(:space_guid1) { create_space(org_guid1) }
    let(:space_guid2) { create_space(org_guid1) }
    let(:space_guid3) { create_space(org_guid2) }
    let(:space_guids) { [space_guid1, space_guid2, space_guid3] }
    let(:app_guid1) { create_app(space_guid1) }
    let(:app_guid2) { create_app(space_guid2) }
    let(:app_guid3) { create_app(space_guid3) }
    let!(:app_guids) { [app_guid1, app_guid2, app_guid3] }

    it 'returns an empty list when the user is a member of no spaces or orgs' do
      response = make_get_request('/v3/apps', user_headers)
      expect(response.code).to eq('200')

      actual_app_guids = response.json_body['resources'].map { |resource| resource['guid'] }
      expect(actual_app_guids).to have(0).items
    end

    [:admin, :admin_read_only, :global_auditor].each do |role|
      it "returns all the spaces when the user is a(n) #{role}" do
        opts = {}
        opts[role] = true

        expected_app_guids = app_guids

        # There may be > 50 results (default page size) due to pollution
        response = make_get_request('/v3/apps?per_page=5000', http_headers(user_token(VCAP::CloudController::User.make, opts)))
        expect(response.code).to eq('200')

        actual_app_guids = response.json_body['resources'].map { |resource| resource['guid'] }

        expected_app_guids.each do |expected_app_guid|
          expect(actual_app_guids).to include(expected_app_guid)
        end
      end
    end

    [:manager].each do |role|
      it "returns all the spaces where the user is an organization #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid1}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request('/v3/apps', user_headers)
        expect(response.code).to eq('200')

        actual_app_guids = response.json_body['resources'].map { |resource| resource['guid'] }
        expected_app_guids = [app_guid1, app_guid2]

        expected_app_guids.each do |expected_app_guid|
          expect(actual_app_guids).to include(expected_app_guid)
        end
      end
    end

    [:user, :billing_manager, :auditor].each do |role|
      it "does not return spaces where the user is an organization #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid1}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_get_request('/v3/apps', user_headers)
        expect(response.code).to eq('200')

        actual_app_guids = response.json_body['resources'].map { |resource| resource['guid'] }

        expect(actual_app_guids).to have(0).items
      end
    end

    [:developer, :manager, :auditor].each do |role|
      it "returns spaces where the user is a space #{role}" do
        org_guids.each do |org_guid|
          response = make_put_request("/v2/organizations/#{org_guid}/users/#{user_guid}", '', admin_headers)
          expect(response.code).to eq('201')
        end

        expected_app_guids = [app_guid1, app_guid3]

        [space_guid1, space_guid3].each do |space_guid|
          response = make_put_request("/v2/spaces/#{space_guid}/#{role}s/#{user_guid}", '', admin_headers)
          expect(response.code).to eq('201')
        end

        response = make_get_request('/v3/apps', user_headers)
        expect(response.code).to eq('200')

        actual_app_guids = response.json_body['resources'].map { |resource| resource['guid'] }

        expect(actual_app_guids).to have(expected_app_guids.size).items
        expected_app_guids.each do |expected_app_guid|
          expect(actual_app_guids).to include(expected_app_guid)
        end
      end
    end
  end

  describe 'POST /v3/apps' do
    let(:org_guid) { create_org }
    let(:space_guid) { create_space(org_guid) }

    let(:body) do
      {
        name: SecureRandom.uuid,
        relationships: {
          space: {
            data: {
              guid: space_guid
            }
          }
        }
      }.to_json
    end

    it 'fails if the user is not associated with the space' do
      response = make_post_request('/v3/apps', body, user_headers)

      expect(response.code).to eq('422')
    end

    [:user, :billing_manager, :auditor, :manager].each do |role|
      it "fails if the user is an organization #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_post_request('/v3/apps', body, user_headers)
        expect(response.code).to eq('422')
      end
    end

    [:auditor, :manager].each do |role|
      it "fails when the user is a space #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/users/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_put_request("/v2/spaces/#{space_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_post_request('/v3/apps', body, user_headers)
        expect(response.code).to eq('422')
      end
    end

    [:developer].each do |role|
      it "succeeds when the user is a space #{role}" do
        response = make_put_request("/v2/organizations/#{org_guid}/users/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_put_request("/v2/spaces/#{space_guid}/#{role}s/#{user_guid}", '', admin_headers)
        expect(response.code).to eq('201')

        response = make_post_request('/v3/apps', body, user_headers)
        expect(response.code).to eq('201')
      end
    end
  end

  def create_user
    body = {
      guid: SecureRandom.uuid
    }.to_json

    response = make_post_request('/v2/users', body, admin_headers)
    expect(response.code).to eq('201')

    response.json_body['metadata']['guid']
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

  def create_app(space_guid)
    body = {
      name: SecureRandom.uuid,
      relationships: {
        space: {
          data: {
            guid: space_guid
          }
        }
      }
    }.to_json

    response = make_post_request('/v3/apps', body, admin_headers)
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
