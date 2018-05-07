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
        response = make_put_request("/v2/organizations/#{org_guid}/managers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')
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
        response = make_put_request("/v2/organizations/#{org_guid}/auditors/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')
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
        response = make_put_request("/v2/organizations/#{org_guid}/billing_managers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')
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
        make_org_user(user, org_guid)
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
        make_org_user(user, org_guid)

        response = make_put_request("/v2/spaces/#{space_guid}/developers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')
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
        make_org_user(user, org_guid)

        response = make_put_request("/v2/spaces/#{space_guid}/managers/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')
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
        make_org_user(user, org_guid)

        response = make_put_request("/v2/spaces/#{space_guid}/auditors/#{user.guid}", '', admin_headers)
        expect(response.code).to eq('201')
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
