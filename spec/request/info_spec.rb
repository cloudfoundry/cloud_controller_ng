require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Info Request' do
  describe 'GET /v3/info' do
    let(:return_info_json) do
      {
        build: TestConfig.config[:info][:build],
        cli_version: {
          minimum: TestConfig.config[:info][:min_cli_version],
          recommended: TestConfig.config[:info][:min_recommended_cli_version]
        },
        custom: TestConfig.config[:info][:custom],
        description: TestConfig.config[:info][:description],
        name: TestConfig.config[:info][:name],
        version: TestConfig.config[:info][:version],
        osbapi_version: TestConfig.config[:info][:osbapi_version],
        links: {
          self: { href: "#{link_prefix}/v3/info" },
          support: { href: TestConfig.config[:info][:support_address] }
        }
      }
    end

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(Rails.root.join('config/osbapi_version').to_s).and_return(true)
      allow(File).to receive(:read).with(Rails.root.join('config/osbapi_version').to_s).and_return('1.0.0')

      TestConfig.override(info: TestConfig.config[:info].merge(osbapi_version: '1.0.0'))
    end

    it 'includes data from the config' do
      get '/v3/info'
      expect(Oj.load(last_response.body)).to match_json_response(return_info_json)
    end

    context 'when no info values are set' do
      let(:return_info_json) do
        {
          build: '',
          cli_version: {
            minimum: '',
            recommended: ''
          },
          custom: {},
          description: '',
          name: '',
          version: 0,
          osbapi_version: '',
          links: {
            self: { href: "#{link_prefix}/v3/info" },
            support: { href: '' }
          }
        }
      end

      before do
        TestConfig.override(info: nil)
        allow(File).to receive(:exist?).with(Rails.root.join('config/osbapi_version').to_s).and_return(false)
      end

      it 'includes has proper empty values' do
        get '/v3/info'
        expect(Oj.load(last_response.body)).to match_json_response(return_info_json)
      end
    end
  end

  describe 'GET /v3/info/usage_summary' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

    let(:api_call) { ->(user_headers) { get '/v3/info/usage_summary', nil, user_headers } }

    let!(:task) { VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::RUNNING_STATE, memory_in_mb: 100) }
    let!(:completed_task) { VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::SUCCEEDED_STATE, memory_in_mb: 100) }
    let!(:started_process1) { VCAP::CloudController::ProcessModelFactory.make(instances: 3, state: 'STARTED', memory: 100) }
    let!(:started_process2) { VCAP::CloudController::ProcessModelFactory.make(instances: 6, state: 'STARTED', memory: 100) }
    let!(:started_process3) { VCAP::CloudController::ProcessModelFactory.make(instances: 7, state: 'STARTED', memory: 100) }
    let!(:stopped_process) { VCAP::CloudController::ProcessModelFactory.make(instances: 2, state: 'STOPPED', memory: 100) }
    let!(:process2) { VCAP::CloudController::ProcessModelFactory.make(instances: 5, state: 'STARTED', memory: 100) }

    let(:info_summary) do
      {
        usage_summary: {
          started_instances: 21,
          memory_in_mb: 2200,
          domains: 1,
          per_app_tasks: 1,
          reserved_ports: 0,
          routes: 0,
          service_instances: 0,
          service_keys: 0
        },
        links: {
          self: { href: "#{link_prefix}/v3/info/usage_summary" }
        }
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new({ code: 404 }.freeze)
      h['admin'] = { code: 200, response_object: info_summary }
      h['admin_read_only'] = { code: 200, response_object: info_summary }
      h['global_auditor'] = { code: 200, response_object: info_summary }
      h
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end
end
