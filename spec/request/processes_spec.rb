require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Processes' do
  RSpec.shared_examples 'process resources with no process_instances' do
    it 'shows an empty array' do
      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)

      if parsed_response['resources'].nil?
        # Single resource
        expect(parsed_response['process_instances']).to eq([])
        expect(parsed_response.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
      else
        # Paginated list
        parsed_response['resources'].each do |process|
          expect(process['process_instances']).to eq([])
          expect(process.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
        end
      end
    end
  end

  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:app_model) { VCAP::CloudController::AppModel.make(space: space, name: 'my_app', droplet: droplet) }
  let(:droplet) { VCAP::CloudController::DropletModel.make }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer, user_name:) }
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let(:user_name) { 'ProcHudson' }
  let(:build_client) { instance_double(HTTPClient, post: nil) }
  let(:metadata) do
    {
      labels: {
        release: 'stable',
        'seriouseats.com/potato' => 'mashed'
      },
      annotations: { 'checksum' => 'SHA' }
    }
  end
  let(:instances_reporters) { instance_double(VCAP::CloudController::InstancesReporters) }
  let(:instances_for_processes) { {} }
  let(:keys_in_order) { %w[readiness_health_check process_instances relationships] }

  before do
    allow_any_instance_of(Diego::Client).to receive(:build_client).and_return(build_client)
  end

  describe 'GET /v3/processes' do
    let!(:web_revision) { VCAP::CloudController::RevisionModel.make }

    let!(:web_process) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        revision: web_revision,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup'
      )
    end
    let!(:worker_process) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        type: 'worker',
        instances: 1,
        memory: 100,
        disk_quota: 200,
        log_rate_limit: 400,
        command: 'start worker'
      )
    end

    before do
      CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
      allow(instances_reporters).to receive(:instances_for_processes).and_return(instances_for_processes)
    end

    it_behaves_like 'list query endpoint' do
      let(:message) { VCAP::CloudController::ProcessesListMessage }
      let(:request) { '/v3/processes' }
      let(:user_header) { developer_headers }

      let(:excluded_params) do
        [
          :app_guid
        ]
      end
      let(:params) do
        {
          guids: %w[foo bar],
          space_guids: %w[foo bar],
          organization_guids: %w[foo bar],
          types: %w[foo bar],
          app_guids: %w[foo bar],
          embed: 'process_instances',
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          label_selector: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 }
        }
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::ProcessModel }

      let(:api_call) do
        ->(headers, filters) { get "/v3/processes?#{filters}", nil, headers }
      end
      let(:headers) { admin_header }
    end

    it 'returns a paginated list of processes' do
      get '/v3/processes?per_page=2', nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 2,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/processes?page=1&per_page=2" },
          'last' => { 'href' => "#{link_prefix}/v3/processes?page=1&per_page=2" },
          'next' => nil,
          'previous' => nil
        },
        'resources' => [
          {
            'guid' => web_process.guid,
            'relationships' => {
              'app' => { 'data' => { 'guid' => app_model.guid } },
              'revision' => {
                'data' => {
                  'guid' => web_revision.guid
                }
              }
            },
            'type' => 'web',
            'command' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'user' => 'vcap',
            'instances' => 2,
            'memory_in_mb' => 1024,
            'disk_in_mb' => 1024,
            'log_rate_limit_in_bytes_per_second' => 1_048_576,
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil,
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'readiness_health_check' => {
              'type' => 'process',
              'data' => {
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'metadata' => { 'annotations' => {}, 'labels' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'version' => web_process.version,
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/processes/#{web_process.guid}" },
              'scale' => { 'href' => "#{link_prefix}/v3/processes/#{web_process.guid}/actions/scale", 'method' => 'POST' },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'stats' => { 'href' => "#{link_prefix}/v3/processes/#{web_process.guid}/stats" },
              'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{web_process.guid}/process_instances" }
            }
          },
          {
            'guid' => worker_process.guid,
            'relationships' => {
              'app' => { 'data' => { 'guid' => app_model.guid } },
              'revision' => nil
            },
            'type' => 'worker',
            'command' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'user' => 'vcap',
            'instances' => 1,
            'memory_in_mb' => 100,
            'disk_in_mb' => 200,
            'log_rate_limit_in_bytes_per_second' => 400,
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil,
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'readiness_health_check' => {
              'type' => 'process',
              'data' => {
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'metadata' => { 'annotations' => {}, 'labels' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'version' => worker_process.version,
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/processes/#{worker_process.guid}" },
              'scale' => { 'href' => "#{link_prefix}/v3/processes/#{worker_process.guid}/actions/scale", 'method' => 'POST' },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'stats' => { 'href' => "#{link_prefix}/v3/processes/#{worker_process.guid}/stats" },
              'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{worker_process.guid}/process_instances" }
            }
          }
        ]
      }

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'filters by label selectors' do
      VCAP::CloudController::ProcessLabelModel.make(key_name: 'fruit', value: 'strawberry', process: worker_process)

      get '/v3/processes?label_selector=fruit=strawberry', {}, developer_headers

      expected_pagination = {
        'total_results' => 1,
        'total_pages' => 1,
        'first' => { 'href' => "#{link_prefix}/v3/processes?label_selector=fruit%3Dstrawberry&page=1&per_page=50" },
        'last' => { 'href' => "#{link_prefix}/v3/processes?label_selector=fruit%3Dstrawberry&page=1&per_page=50" },
        'next' => nil,
        'previous' => nil
      }

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources'].count).to eq(1)
      expect(parsed_response['resources'][0]['guid']).to eq(worker_process.guid)
      expect(parsed_response['pagination']).to eq(expected_pagination)
    end

    context 'faceted list' do
      context 'by types' do
        it 'returns only the matching processes' do
          get '/v3/processes?per_page=2&types=worker,doesnotexist', nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/processes?page=1&per_page=2&types=worker%2Cdoesnotexist" },
            'last' => { 'href' => "#{link_prefix}/v3/processes?page=1&per_page=2&types=worker%2Cdoesnotexist" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)

          parsed_response = Oj.load(last_response.body)

          returned_guids = parsed_response['resources'].pluck('guid')
          expect(returned_guids).to contain_exactly(worker_process.guid)
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by space_guids' do
        let(:other_space) { VCAP::CloudController::Space.make(organization: space.organization) }
        let(:other_app_model) { VCAP::CloudController::AppModel.make(space: other_space) }
        let!(:other_space_process) do
          VCAP::CloudController::ProcessModel.make(
            :process,
            app: other_app_model,
            type: 'web',
            instances: 2,
            memory: 1024,
            disk_quota: 1024,
            log_rate_limit: 1_048_576,
            command: 'rackup'
          )
        end

        before do
          other_space.add_developer developer
        end

        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&space_guids=#{other_space.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/processes?page=1&per_page=2&space_guids=#{other_space.guid}" },
            'last' => { 'href' => "#{link_prefix}/v3/processes?page=1&per_page=2&space_guids=#{other_space.guid}" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)

          parsed_response = Oj.load(last_response.body)

          returned_guids = parsed_response['resources'].pluck('guid')
          expect(returned_guids).to contain_exactly(other_space_process.guid)
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by organization guids' do
        let(:other_space) { VCAP::CloudController::Space.make }
        let!(:other_org) { other_space.organization }
        let!(:other_space_process) do
          VCAP::CloudController::ProcessModel.make(
            :process,
            app: other_app_model,
            type: 'web',
            instances: 2,
            memory: 1024,
            disk_quota: 1024,
            log_rate_limit: 1_048_576,
            command: 'rackup'
          )
        end
        let(:other_app_model) { VCAP::CloudController::AppModel.make(space: other_space) }
        let(:developer) { make_developer_for_space(other_space) }

        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&organization_guids=#{other_org.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/processes?organization_guids=#{other_org.guid}&page=1&per_page=2" },
            'last' => { 'href' => "#{link_prefix}/v3/processes?organization_guids=#{other_org.guid}&page=1&per_page=2" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)

          parsed_response = Oj.load(last_response.body)

          returned_guids = parsed_response['resources'].pluck('guid')
          expect(returned_guids).to contain_exactly(other_space_process.guid)
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by app guids' do
        let(:desired_app) { VCAP::CloudController::AppModel.make(space:) }
        let!(:desired_process) do
          VCAP::CloudController::ProcessModel.make(:process,
                                                   app: desired_app,
                                                   type: 'persnickety',
                                                   instances: 3,
                                                   memory: 2048,
                                                   disk_quota: 2048,
                                                   log_rate_limit: 2_097_152,
                                                   command: 'at ease')
        end

        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&app_guids=#{desired_app.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/processes?app_guids=#{desired_app.guid}&page=1&per_page=2" },
            'last' => { 'href' => "#{link_prefix}/v3/processes?app_guids=#{desired_app.guid}&page=1&per_page=2" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)

          parsed_response = Oj.load(last_response.body)

          returned_guids = parsed_response['resources'].pluck('guid')
          expect(returned_guids).to contain_exactly(desired_process.guid)
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by guids' do
        it 'returns only the matching processes' do
          get "/v3/processes?per_page=2&guids=#{web_process.guid},#{worker_process.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/processes?guids=#{web_process.guid}%2C#{worker_process.guid}&page=1&per_page=2" },
            'last' => { 'href' => "#{link_prefix}/v3/processes?guids=#{web_process.guid}%2C#{worker_process.guid}&page=1&per_page=2" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)

          parsed_response = Oj.load(last_response.body)

          returned_guids = parsed_response['resources'].pluck('guid')
          expect(returned_guids).to contain_exactly(web_process.guid, worker_process.guid)
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end
    end

    context 'with embed=process_instances' do
      let(:instances_for_processes) do
        {
          web_process.guid => {
            0 => { state: 'RUNNING', since: 111 },
            1 => { state: 'STARTING', since: 222 }
          },
          worker_process.guid => {
            0 => { state: 'RUNNING', since: 333 },
            1 => { state: 'DOWN', since: 444 }
          }
        }
      end

      it 'shows the embedded process_instances arrays' do
        get '/v3/processes?embed=process_instances', nil, developer_headers

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)

        parsed_response['resources'].find { |resource| resource['guid'] == web_process.guid }.tap do |process|
          expect(process['process_instances']).to eq([{ 'index' => 0, 'state' => 'RUNNING', 'since' => 111 }, { 'index' => 1, 'state' => 'STARTING', 'since' => 222 }])
          expect(process.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
        end
        parsed_response['resources'].find { |resource| resource['guid'] == worker_process.guid }.tap do |process|
          expect(process['process_instances']).to eq([{ 'index' => 0, 'state' => 'RUNNING', 'since' => 333 }, { 'index' => 1, 'state' => 'DOWN', 'since' => 444 }])
          expect(process.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
        end
      end

      context 'when there are no instances' do
        let(:instances_for_processes) { { web_process.guid => {}, worker_process.guid => {} } }

        before { get '/v3/processes?embed=process_instances', nil, developer_headers }

        it_behaves_like 'process resources with no process_instances'
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { get '/v3/processes', nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_guids: [web_process.guid, worker_process.guid] }.freeze)
        h['org_auditor'] = { code: 200, response_guids: [] }
        h['org_billing_manager'] = { code: 200, response_guids: [] }
        h['no_role'] = { code: 200, response_objects: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end
  end

  describe 'GET /v3/processes/:guid' do
    let(:revision) { VCAP::CloudController::RevisionModel.make }
    let(:process) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        revision: revision,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup'
      )
    end
    let(:expected_response) do
      {
        'guid' => process.guid,
        'type' => 'web',
        'relationships' => {
          'app' => { 'data' => { 'guid' => app_model.guid } },
          'revision' => { 'data' => { 'guid' => revision.guid } }
        },
        'command' => 'rackup',
        'user' => 'vcap',
        'instances' => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb' => 1024,
        'log_rate_limit_in_bytes_per_second' => 1_048_576,
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil,
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'readiness_health_check' => {
          'type' => 'process',
          'data' => {
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'metadata' => { 'annotations' => {}, 'labels' => {} },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'version' => process.version,
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/actions/scale", 'method' => 'POST' },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
          'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/stats" },
          'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/process_instances" }
        }
      }
    end

    it 'retrieves the process' do
      get "/v3/processes/#{process.guid}", nil, developer_headers

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'redacts information for auditors' do
      auditor = VCAP::CloudController::User.make
      space.organization.add_user(auditor)
      space.add_auditor(auditor)

      get "/v3/processes/#{process.guid}", nil, headers_for(auditor)

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['command']).to eq('[PRIVATE DATA HIDDEN]')
    end

    context 'with embed=process_instances' do
      let(:instances_for_processes) do
        {
          process.guid => {
            0 => { state: 'RUNNING', since: 111 },
            1 => { state: 'STARTING', since: 222 }
          }
        }
      end
      let(:expected_response) do
        a = super().to_a
        before_relationships = a.index { |k, _| k == 'relationships' } || a.length
        a.insert(before_relationships, ['process_instances', [
          { 'index' => 0, 'state' => 'RUNNING', 'since' => 111 },
          { 'index' => 1, 'state' => 'STARTING', 'since' => 222 }
        ]])
        a.to_h
      end

      before do
        CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
        allow(instances_reporters).to receive(:instances_for_processes).and_return(instances_for_processes)
      end

      it 'shows the embedded process_instances array' do
        get "/v3/processes/#{process.guid}?embed=process_instances", nil, developer_headers

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)
        expect(parsed_response.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
      end

      context 'when there are no instances' do
        let(:instances_for_processes) { { process.guid => {} } }

        before { get "/v3/processes/#{process.guid}?embed=process_instances", nil, developer_headers }

        it_behaves_like 'process resources with no process_instances'
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { get "/v3/processes/#{process.guid}", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_object: expected_response.merge({ 'command' => '[PRIVATE DATA HIDDEN]' }) }.freeze)
        h['space_developer'] = { code: 200, response_object: expected_response }
        h['admin'] = { code: 200, response_object: expected_response }
        h['admin_read_only'] = { code: 200, response_object: expected_response }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404, response_object: nil }
        h['no_role'] = { code: 404, response_object: nil }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'GET stats' do
    let(:process) { VCAP::CloudController::ProcessModel.make(:process, type: 'worker', app: app_model) }
    let(:net_info_1) do
      {
        address: '1.2.3.4',
        instance_address: '5.6.7.8',
        ports: [
          {
            host_port: 8080,
            container_port: 1234,
            host_tls_proxy_port: 61_002,
            container_tls_proxy_port: 61_003
          },
          {
            host_port: 3000,
            container_port: 4000,
            host_tls_proxy_port: 61_006,
            container_tls_proxy_port: 61_007
          }
        ]
      }
    end

    let(:stats_for_process) do
      {
        0 => {
          state: 'RUNNING',
          routable: true,
          details: 'some-details',
          isolation_segment: 'very-isolated',
          stats: {
            name: process.name,
            uris: process.uris,
            host: 'toast',
            instance_guid: 'some-diego-instance-id',
            net_info: net_info_1,
            uptime: 12_345,
            mem_quota: process[:memory] * 1024 * 1024,
            disk_quota: process[:disk_quota] * 1024 * 1024,
            log_rate_limit: process[:log_rate_limit],
            fds_quota: process.file_descriptors,
            usage: {
              time: usage_time,
              cpu: 0.8,
              cpu_entitlement: 0.1,
              mem: 128,
              disk: 1024,
              log_rate: 1024
            }
          }
        }
      }
    end

    let(:instances_reporters) { double(:instances_reporters) }
    let(:usage_time) { Time.now.utc.to_s }

    let(:expected_response) do
      {
        'resources' => [{
          'type' => 'worker',
          'index' => 0,
          'state' => 'RUNNING',
          'instance_guid' => 'some-diego-instance-id',
          'routable' => true,
          'isolation_segment' => 'very-isolated',
          'details' => 'some-details',
          'usage' => {
            'time' => usage_time,
            'cpu' => 0.8,
            'cpu_entitlement' => 0.1,
            'mem' => 128,
            'disk' => 1024,
            'log_rate' => 1024
          },
          'host' => 'toast',
          'instance_internal_ip' => '5.6.7.8',
          'instance_ports' => [
            {
              'external' => 8080,
              'internal' => 1234,
              'external_tls_proxy_port' => 61_002,
              'internal_tls_proxy_port' => 61_003
            },
            {
              'external' => 3000,
              'internal' => 4000,
              'external_tls_proxy_port' => 61_006,
              'internal_tls_proxy_port' => 61_007
            }
          ],
          'uptime' => 12_345,
          'mem_quota' => 1_073_741_824,
          'disk_quota' => 1_073_741_824,
          'fds_quota' => 16_384,
          'log_rate_limit' => 1_048_576
        }]
      }
    end

    before do
      CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
      allow(instances_reporters).to receive(:stats_for_app).and_return([stats_for_process, []])
    end

    describe 'GET /v3/processes/:guid/stats' do
      context 'route integrity is enabled' do
        it 'retrieves the stats for a process' do
          get "/v3/processes/#{process.guid}/stats", nil, developer_headers

          parsed_response = Oj.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end

      context 'cpu entitlement usage is not available' do
        before do
          stats_for_process[0][:stats][:usage][:cpu_entitlement] = nil
        end

        it 'returns cpu entitlement as null' do
          get "/v3/processes/#{process.guid}/stats", nil, developer_headers

          parsed_response = Oj.load(last_response.body)

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'][0]['usage']['cpu_entitlement']).to be_nil
        end
      end
    end

    describe 'GET /v3/apps/:guid/processes/:type/stats' do
      it 'retrieves the stats for a process belonging to an app' do
        get "/v3/apps/#{app_model.guid}/processes/worker/stats", nil, developer_headers

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { get "/v3/processes/#{process.guid}/stats", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_object: expected_response }.freeze)
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404, response_object: [] }
        h['no_role'] = { code: 404, response_object: [] }
        h
      end

      # while this endpoint returns a list, it's easier to test as a single object since it doesn't paginate
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'GET /v3/processes/:guid/process_instances' do
    let(:process) { VCAP::CloudController::ProcessModel.make(:process, app: app_model, state: VCAP::CloudController::ProcessModel::STARTED) }
    let(:two_days_ago_since_epoch_ns) { 2.days.ago.to_f * 1e9 }
    let(:two_days_in_seconds) { 60 * 60 * 24 * 2 }
    let(:second_in_ns) { 1_000_000_000 }
    let(:actual_lrp_0) do
      Diego::Bbs::Models::ActualLRP.new(
        actual_lrp_key: Diego::Bbs::Models::ActualLRPKey.new(process_guid: process.guid + 'version', index: 0),
        actual_lrp_instance_key: Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-a'),
        state: Diego::ActualLRPState::RUNNING,
        placement_error: '',
        since: two_days_ago_since_epoch_ns
      )
    end
    let(:actual_lrp_1) do
      Diego::Bbs::Models::ActualLRP.new(
        actual_lrp_key: Diego::Bbs::Models::ActualLRPKey.new(process_guid: process.guid + 'version', index: 1),
        actual_lrp_instance_key: Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-b'),
        state: Diego::ActualLRPState::CLAIMED,
        placement_error: '',
        since: two_days_ago_since_epoch_ns + (1 * second_in_ns)
      )
    end
    let(:bbs_response) { Diego::Bbs::Models::ActualLRPsByProcessGuidsResponse.new(actual_lrps: [actual_lrp_0, actual_lrp_1]) }
    let(:bbs_client) { double(:bbs_client) }

    let(:expected_response) do
      {
        'resources' => [{
          'index' => 0,
          'state' => 'RUNNING',
          'since' => two_days_in_seconds
        }, {
          'index' => 1,
          'state' => 'STARTING',
          'since' => two_days_in_seconds - 1
        }],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/process_instances" },
          'process' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}" }
        }
      }
    end

    before do
      CloudController::DependencyLocator.instance.register(:bbs_instances_client, VCAP::CloudController::Diego::BbsInstancesClient.new(bbs_client))
      allow(bbs_client).to receive(:actual_lrps_by_process_guids).and_return(bbs_response)
    end

    it 'retrieves all process instances for the process' do
      get "/v3/processes/#{process.guid}/process_instances", nil, developer_headers

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { get "/v3/processes/#{process.guid}/process_instances", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_object: expected_response }.freeze)
        h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404, response_object: [] }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'PATCH /v3/processes/:guid' do
    let(:revision) { VCAP::CloudController::RevisionModel.make }
    let(:process) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        revision: revision,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup',
        ports: [4444, 5555],
        health_check_type: 'port',
        health_check_timeout: 10,
        health_check_interval: 5
      )
    end

    let(:update_request) do
      {
        command: 'new command',
        health_check: {
          type: 'process',
          data: {
            timeout: 20,
            interval: 5
          }
        },
        readiness_health_check: {
          type: 'port',
          data: {
            invocation_timeout: 10,
            interval: 6
          }
        },
        metadata: metadata
      }.to_json
    end

    let(:expected_response) do
      {
        'guid' => process.guid,
        'relationships' => {
          'app' => { 'data' => { 'guid' => app_model.guid } },
          'revision' => { 'data' => { 'guid' => revision.guid } }
        },
        'type' => 'web',
        'command' => 'new command',
        'user' => 'vcap',
        'instances' => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb' => 1024,
        'log_rate_limit_in_bytes_per_second' => 1_048_576,
        'health_check' => {
          'type' => 'process',
          'data' => {
            'timeout' => 20,
            'invocation_timeout' => nil,
            'interval' => 5
          }
        },
        'readiness_health_check' => {
          'type' => 'port',
          'data' => {
            'invocation_timeout' => 10,
            'interval' => 6
          }
        },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'version' => process.version,
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/actions/scale", 'method' => 'POST' },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
          'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/stats" },
          'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/process_instances" }
        },
        'metadata' => {
          'labels' => {
            'release' => 'stable',
            'seriouseats.com/potato' => 'mashed'
          },
          'annotations' => { 'checksum' => 'SHA' }
        }
      }
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { patch "/v3/processes/#{process.guid}", update_request, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['admin'] = { code: 200, response_object: expected_response }
        h['space_developer'] = { code: 200, response_object: expected_response }
        h['space_supporter'] = { code: 200, response_object: expected_response }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    it 'updates the process' do
      patch "/v3/processes/#{process.guid}", update_request, developer_headers.merge('CONTENT_TYPE' => 'application/json')

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.command).to eq('new command')
      expect(process.health_check_type).to eq('process')
      expect(process.health_check_timeout).to eq(20)
      expect(process.readiness_health_check_type).to eq('port')
      expect(process.readiness_health_check_invocation_timeout).to eq(10)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.app.process.update',
                                        actee: app_model.guid,
                                        actee_type: 'app',
                                        actee_name: 'my_app',
                                        actor: developer.guid,
                                        actor_type: 'user',
                                        actor_username: user_name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata).to eq({
                                     'process_guid' => process.guid,
                                     'process_type' => 'web',
                                     'request' => {
                                       'command' => '[PRIVATE DATA HIDDEN]',
                                       'health_check' => {
                                         'type' => 'process',
                                         'data' => {
                                           'timeout' => 20,
                                           'interval' => 5
                                         }
                                       },
                                       'readiness_health_check' => {
                                         'type' => 'port',
                                         'data' => {
                                           'invocation_timeout' => 10,
                                           'interval' => 6
                                         }
                                       },
                                       'metadata' => {
                                         'labels' => {
                                           'release' => 'stable',
                                           'seriouseats.com/potato' => 'mashed'
                                         },
                                         'annotations' => { 'checksum' => 'SHA' }
                                       }
                                     }
                                   })
    end
  end

  describe 'POST /v3/processes/:guid/actions/scale' do
    let(:process) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup'
      )
    end

    let(:scale_request) do
      {
        instances: 5,
        memory_in_mb: 10,
        disk_in_mb: 20,
        log_rate_limit_in_bytes_per_second: 40
      }
    end

    let(:expected_response) do
      {
        'guid' => process.guid,
        'type' => 'web',

        'relationships' => {
          'app' => { 'data' => { 'guid' => app_model.guid } },
          'revision' => nil
        },
        'command' => 'rackup',
        'user' => 'vcap',
        'instances' => 5,
        'memory_in_mb' => 10,
        'disk_in_mb' => 20,
        'log_rate_limit_in_bytes_per_second' => 40,
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil,
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'readiness_health_check' => {
          'type' => 'process',
          'data' => {
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'metadata' => { 'annotations' => {}, 'labels' => {} },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'version' => process.version,
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/actions/scale", 'method' => 'POST' },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
          'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/stats" },
          'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/process_instances" }
        }
      }
    end

    it 'scales the process' do
      post "/v3/processes/#{process.guid}/actions/scale", scale_request.to_json, developer_headers

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.instances).to eq(5)
      expect(process.memory).to eq(10)
      expect(process.disk_quota).to eq(20)
      expect(process.log_rate_limit).to eq(40)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all

      process_event = events.find { |e| e.type == 'audit.app.process.scale' }
      expect(process_event.values).to include({
                                                type: 'audit.app.process.scale',
                                                actee: app_model.guid,
                                                actee_type: 'app',
                                                actee_name: 'my_app',
                                                actor: developer.guid,
                                                actor_type: 'user',
                                                actor_username: user_name,
                                                space_guid: space.guid,
                                                organization_guid: space.organization.guid
                                              })
      expect(process_event.metadata).to eq({
                                             'process_guid' => process.guid,
                                             'process_type' => 'web',
                                             'request' => {
                                               'instances' => 5,
                                               'memory_in_mb' => 10,
                                               'disk_in_mb' => 20,
                                               'log_rate_limit_in_bytes_per_second' => 40
                                             }
                                           })
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { post "/v3/processes/#{process.guid}/actions/scale", scale_request.to_json, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['admin'] = { code: 202, response_object: expected_response }
        h['space_developer'] = { code: 202, response_object: expected_response }
        h['space_supporter'] = { code: 202, response_object: expected_response }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the user is assigned the space_supporter role' do
      let(:space_supporter) do
        user = VCAP::CloudController::User.make
        org.add_user(user)
        space.add_supporter(user)
        user
      end

      it 'can scale a process' do
        scale_request = {
          instances: 5,
          memory_in_mb: 10,
          disk_in_mb: 20,
          log_rate_limit_in_bytes_per_second: 40
        }

        post "/v3/processes/#{process.guid}/actions/scale", scale_request.to_json, headers_for(space_supporter)

        expect(last_response.status).to eq(202)
        expect(parsed_response).to be_a_response_like(expected_response)

        process.reload
        expect(process.instances).to eq(5)
        expect(process.memory).to eq(10)
        expect(process.disk_quota).to eq(20)
        expect(process.log_rate_limit).to eq(40)
      end
    end

    it 'returns a helpful error when the memory is too large' do
      scale_request = {
        memory_in_mb: 100_000_000_000
      }

      post "/v3/processes/#{process.guid}/actions/scale", scale_request.to_json, developer_headers

      expect(last_response.status).to eq(422)
      expect(parsed_response['errors'][0]['detail']).to eq 'Memory in mb must be less than or equal to 2147483647'

      process.reload
      expect(process.memory).to eq(1024)
    end

    it 'ensures that the memory allocation is greater than existing sidecar memory allocation' do
      sidecar = VCAP::CloudController::SidecarModel.make(
        name: 'my-sidecar',
        app: app_model,
        memory: 256
      )
      VCAP::CloudController::SidecarProcessTypeModel.make(sidecar: sidecar, type: process.type, app_guid: app_model.guid)

      scale_request = {
        memory_in_mb: 256
      }

      post "/v3/processes/#{process.guid}/actions/scale", scale_request.to_json, developer_headers

      expect(last_response.status).to eq(422)
      expect(parsed_response['errors'][0]['detail']).to eq 'The requested memory allocation is not large enough to run all of your sidecar processes'

      process.reload
      expect(process.memory).to eq(1024)
    end

    it 'returns a helpful error when the log quota is too small' do
      scale_request = {
        log_rate_limit_in_bytes_per_second: -2
      }

      post "/v3/processes/#{process.guid}/actions/scale", scale_request.to_json, developer_headers

      expect(last_response.status).to eq(422)
      expect(parsed_response['errors'][0]['detail']).to eq 'Log rate limit in bytes per second must be greater than or equal to -1'

      process.reload
      expect(process.log_rate_limit).to eq(1_048_576)
    end

    context 'telemetry' do
      let(:process) do
        VCAP::CloudController::ProcessModel.make(
          :process,
          app: app_model,
          type: 'web',
          instances: 2,
          memory: 1024,
          disk_quota: 1024,
          log_rate_limit: 1_048_576,
          command: 'rackup'
        )
      end

      let(:scale_request) do
        {
          instances: 5,
          memory_in_mb: 10,
          disk_in_mb: 20,
          log_rate_limit_in_bytes_per_second: 40
        }
      end

      it 'logs the required fields when the process gets scaled' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'scale-app' => {
              'api-version' => 'v3',
              'instance-count' => 5,
              'memory-in-mb' => 10,
              'disk-in-mb' => 20,
              'log-rate-in-bytes-per-second' => 40,
              'process-type' => 'web',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(process.app.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(developer.guid)
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))
          post "/v3/processes/#{process.guid}/actions/scale", scale_request.to_json, developer_headers

          expect(last_response.status).to eq(202), last_response.body
        end
      end
    end
  end

  describe 'DELETE /v3/processes/:guid/instances/:index' do
    before do
      allow_any_instance_of(VCAP::CloudController::Diego::BbsAppsClient).to receive(:stop_index)
    end

    it 'terminates a single instance of a process' do
      process = VCAP::CloudController::ProcessModel.make(:process, type: 'web', app: app_model)

      delete "/v3/processes/#{process.guid}/instances/0", nil, developer_headers

      expect(last_response.status).to eq(204)

      events        = VCAP::CloudController::Event.where(actor: developer.guid).all
      process_event = events.find { |e| e.type == 'audit.app.process.terminate_instance' }
      expect(process_event.values).to include({
                                                type: 'audit.app.process.terminate_instance',
                                                actee: app_model.guid,
                                                actee_type: 'app',
                                                actee_name: 'my_app',
                                                actor: developer.guid,
                                                actor_type: 'user',
                                                actor_username: user_name,
                                                space_guid: space.guid,
                                                organization_guid: space.organization.guid
                                              })
      expect(process_event.metadata).to eq({
                                             'process_guid' => process.guid,
                                             'process_type' => 'web',
                                             'process_index' => 0
                                           })
    end

    context 'permissions' do
      let(:process) { VCAP::CloudController::ProcessModel.make(:process, type: 'web', app: app_model) }

      let(:api_call) { ->(user_headers) { delete "/v3/processes/#{process.guid}/instances/0", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['admin'] = { code: 204 }
        h['space_developer'] = { code: 204 }
        h['space_supporter'] = { code: 204 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end
  end

  describe 'GET /v3/apps/:guid/processes' do
    let!(:process1) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup'
      )
    end

    let!(:process2) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        revision: revision2,
        type: 'worker',
        instances: 1,
        memory: 100,
        disk_quota: 200,
        log_rate_limit: 400,
        command: 'start worker'
      )
    end

    let!(:process3) do
      VCAP::CloudController::ProcessModel.make(:process, app: app_model, revision: revision3)
    end

    let!(:deployment_process) do
      VCAP::CloudController::ProcessModel.make(:process, app: app_model, type: 'web-deployment', revision: deployment_revision)
    end
    let!(:revision3) { VCAP::CloudController::RevisionModel.make }
    let!(:revision2) { VCAP::CloudController::RevisionModel.make }
    let!(:deployment_revision) { VCAP::CloudController::RevisionModel.make }

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::ProcessModel }
      let(:additional_resource_params) { { app: app_model } }
      let(:api_call) do
        ->(headers, filters) { get "/v3/apps/#{app_model.guid}/processes?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end

    it 'returns a paginated list of processes for an app' do
      get "/v3/apps/#{app_model.guid}/processes?per_page=2", nil, developer_headers

      expected_response = {
        'pagination' => {
          'total_results' => 4,
          'total_pages' => 2,
          'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes?page=1&per_page=2" },
          'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes?page=2&per_page=2" },
          'next' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes?page=2&per_page=2" },
          'previous' => nil
        },
        'resources' => [
          {
            'guid' => process1.guid,
            'relationships' => {
              'app' => { 'data' => { 'guid' => app_model.guid } },
              'revision' => nil
            },
            'type' => 'web',
            'command' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'user' => 'vcap',
            'instances' => 2,
            'memory_in_mb' => 1024,
            'disk_in_mb' => 1024,
            'log_rate_limit_in_bytes_per_second' => 1_048_576,
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil,
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'readiness_health_check' => {
              'type' => 'process',
              'data' => {
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'metadata' => { 'annotations' => {}, 'labels' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'version' => process1.version,
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/processes/#{process1.guid}" },
              'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process1.guid}/actions/scale", 'method' => 'POST' },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process1.guid}/stats" },
              'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process1.guid}/process_instances" }
            }
          },
          {
            'guid' => process2.guid,
            'relationships' => {
              'app' => { 'data' => { 'guid' => app_model.guid } },
              'revision' => {
                'data' => {
                  'guid' => revision2.guid
                }
              }
            },
            'type' => 'worker',
            'command' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'user' => 'vcap',
            'instances' => 1,
            'memory_in_mb' => 100,
            'disk_in_mb' => 200,
            'log_rate_limit_in_bytes_per_second' => 400,
            'health_check' => {
              'type' => 'port',
              'data' => {
                'timeout' => nil,
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'readiness_health_check' => {
              'type' => 'process',
              'data' => {
                'invocation_timeout' => nil,
                'interval' => nil
              }
            },
            'metadata' => { 'annotations' => {}, 'labels' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'version' => process2.version,
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/processes/#{process2.guid}" },
              'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process2.guid}/actions/scale", 'method' => 'POST' },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process2.guid}/stats" },
              'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process2.guid}/process_instances" }
            }
          }
        ]
      }

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted list' do
      context 'by types' do
        it 'returns only the matching processes' do
          get "/v3/apps/#{app_model.guid}/processes?per_page=2&types=worker", nil, developer_headers

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes?page=1&per_page=2&types=worker" },
            'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes?page=1&per_page=2&types=worker" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)

          parsed_response = Oj.load(last_response.body)

          returned_guids = parsed_response['resources'].pluck('guid')
          expect(returned_guids).to contain_exactly(process2.guid)
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end

      context 'by guids' do
        it 'returns only the matching processes' do
          get "/v3/apps/#{app_model.guid}/processes?per_page=2&guids=#{process1.guid},#{process2.guid}", nil, developer_headers

          expected_pagination = {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes?guids=#{process1.guid}%2C#{process2.guid}&page=1&per_page=2" },
            'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes?guids=#{process1.guid}%2C#{process2.guid}&page=1&per_page=2" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)

          parsed_response = Oj.load(last_response.body)

          returned_guids = parsed_response['resources'].pluck('guid')
          expect(returned_guids).to contain_exactly(process1.guid, process2.guid)
          expect(parsed_response['pagination']).to be_a_response_like(expected_pagination)
        end
      end
    end

    context 'with embed=process_instances' do
      let(:instances_for_processes) do
        {
          process1.guid => { 0 => { state: 'RUNNING', since: 111 } },
          process2.guid => { 0 => { state: 'STARTING', since: 222 } },
          process3.guid => { 0 => { state: 'DOWN', since: 333 } },
          deployment_process.guid => {}
        }
      end

      before do
        CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
        allow(instances_reporters).to receive(:instances_for_processes).and_return(instances_for_processes)
      end

      it 'shows the embedded process_instances arrays (empty if there are no instances)' do
        get "/v3/apps/#{app_model.guid}/processes?embed=process_instances", nil, developer_headers

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)

        parsed_response['resources'].find { |resource| resource['guid'] == process1.guid }.tap do |process|
          expect(process['process_instances']).to eq([{ 'index' => 0, 'state' => 'RUNNING', 'since' => 111 }])
          expect(process.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
        end
        parsed_response['resources'].find { |resource| resource['guid'] == process2.guid }.tap do |process|
          expect(process['process_instances']).to eq([{ 'index' => 0, 'state' => 'STARTING', 'since' => 222 }])
          expect(process.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
        end
        parsed_response['resources'].find { |resource| resource['guid'] == process3.guid }.tap do |process|
          expect(process['process_instances']).to eq([{ 'index' => 0, 'state' => 'DOWN', 'since' => 333 }])
          expect(process.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
        end
        parsed_response['resources'].find { |resource| resource['guid'] == deployment_process.guid }.tap do |process|
          expect(process['process_instances']).to eq([])
          expect(process.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
        end
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/processes", nil, user_headers } }
      let(:expected_guids) { [process1.guid, process2.guid, process3.guid, deployment_process.guid] }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_guids: expected_guids }.freeze)
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404, response_guids: nil }
        h['no_role'] = { code: 404, response_guids: nil }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end
  end

  describe 'GET /v3/apps/:guid/processes/:type' do
    let!(:process) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        revision: revision,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup'
      )
    end
    let!(:revision) { VCAP::CloudController::RevisionModel.make }
    let(:expected_response) do
      {
        'guid' => process.guid,
        'relationships' => {
          'app' => { 'data' => { 'guid' => app_model.guid } },
          'revision' => { 'data' => { 'guid' => revision.guid } }
        },
        'type' => 'web',
        'command' => 'rackup',
        'user' => 'vcap',
        'instances' => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb' => 1024,
        'log_rate_limit_in_bytes_per_second' => 1_048_576,
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil,
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'readiness_health_check' => {
          'type' => 'process',
          'data' => {
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'metadata' => { 'annotations' => {}, 'labels' => {} },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'version' => process.version,
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/actions/scale", 'method' => 'POST' },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
          'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/stats" },
          'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/process_instances" }
        }
      }
    end

    before do
      CloudController::DependencyLocator.instance.register(:instances_reporters, instances_reporters)
      allow(instances_reporters).to receive(:instances_for_processes).and_return(instances_for_processes)
    end

    it 'retrieves the process for an app with the requested type' do
      get "/v3/apps/#{app_model.guid}/processes/web", nil, developer_headers

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    it 'redacts information for auditors' do
      VCAP::CloudController::ProcessModel.make(:process, app: app_model, type: 'web', command: 'rackup')

      auditor = VCAP::CloudController::User.make
      space.organization.add_user(auditor)
      space.add_auditor(auditor)

      get "/v3/apps/#{app_model.guid}/processes/web", nil, headers_for(auditor)

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['command']).to eq('[PRIVATE DATA HIDDEN]')
    end

    context 'with embed=process_instances' do
      let(:instances_for_processes) do
        {
          process.guid => {
            0 => { state: 'RUNNING', since: 111 },
            1 => { state: 'STARTING', since: 222 }
          }
        }
      end

      it 'shows the embedded process_instances arrays' do
        get "/v3/apps/#{app_model.guid}/processes/web?embed=process_instances", nil, developer_headers

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)

        expect(parsed_response['process_instances']).to eq([{ 'index' => 0, 'state' => 'RUNNING', 'since' => 111 }, { 'index' => 1, 'state' => 'STARTING', 'since' => 222 }])
        expect(parsed_response.keys.each_cons(keys_in_order.size)).to include(keys_in_order)
      end

      context 'when there are no instances' do
        let(:instances_for_processes) { { process.guid => {} } }

        before { get "/v3/apps/#{app_model.guid}/processes/web?embed=process_instances", nil, developer_headers }

        it_behaves_like 'process resources with no process_instances'
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/processes/web", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_object: expected_response.merge({ 'command' => '[PRIVATE DATA HIDDEN]' }) }.freeze)
        h['space_developer'] = { code: 200, response_object: expected_response }
        h['admin'] = { code: 200, response_object: expected_response }
        h['admin_read_only'] = { code: 200, response_object: expected_response }
        h['org_billing_manager'] = { code: 404, response_object: nil }
        h['org_auditor'] = { code: 404, response_object: nil }
        h['no_role'] = { code: 404, response_object: nil }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'PATCH /v3/apps/:guid/processes/:type' do
    it 'updates the process' do
      process = VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup',
        ports: [4444, 5555],
        health_check_type: 'port',
        health_check_timeout: 10,
        readiness_health_check_type: 'process'
      )

      update_request = {
        command: 'new command',
        user: 'containeruser',
        health_check: {
          type: 'http',
          data: {
            timeout: 20,
            endpoint: '/healthcheck'
          }
        },
        readiness_health_check: {
          type: 'http',
          data: {
            invocation_timeout: 10,
            interval: 7,
            endpoint: '/ready'
          }
        },
        metadata: metadata
      }.to_json

      patch "/v3/apps/#{app_model.guid}/processes/web", update_request, developer_headers.merge('CONTENT_TYPE' => 'application/json')

      expected_response = {
        'guid' => process.guid,
        'relationships' => {
          'app' => { 'data' => { 'guid' => app_model.guid } },
          'revision' => nil
        },
        'type' => 'web',
        'command' => 'new command',
        'user' => 'containeruser',
        'instances' => 2,
        'memory_in_mb' => 1024,
        'disk_in_mb' => 1024,
        'log_rate_limit_in_bytes_per_second' => 1_048_576,
        'health_check' => {
          'type' => 'http',
          'data' => {
            'timeout' => 20,
            'endpoint' => '/healthcheck',
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'readiness_health_check' => {
          'type' => 'http',
          'data' => {
            'endpoint' => '/ready',
            'invocation_timeout' => 10,
            'interval' => 7
          }
        },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'version' => process.version,
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/actions/scale", 'method' => 'POST' },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
          'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/stats" },
          'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/process_instances" }
        },
        'metadata' => {
          'labels' => {
            'release' => 'stable',
            'seriouseats.com/potato' => 'mashed'
          },
          'annotations' => { 'checksum' => 'SHA' }
        }
      }

      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.command).to eq('new command')
      expect(process.user).to eq('containeruser')
      expect(process.health_check_type).to eq('http')
      expect(process.health_check_timeout).to eq(20)
      expect(process.health_check_http_endpoint).to eq('/healthcheck')

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.app.process.update',
                                        actee: app_model.guid,
                                        actee_type: 'app',
                                        actee_name: 'my_app',
                                        actor: developer.guid,
                                        actor_type: 'user',
                                        actor_username: user_name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata).to eq({
                                     'process_guid' => process.guid,
                                     'process_type' => 'web',
                                     'request' => {
                                       'command' => '[PRIVATE DATA HIDDEN]',
                                       'user' => 'containeruser',
                                       'health_check' => {
                                         'type' => 'http',
                                         'data' => {
                                           'timeout' => 20,
                                           'endpoint' => '/healthcheck'
                                         }
                                       },
                                       'readiness_health_check' => {
                                         'type' => 'http',
                                         'data' => {
                                           'endpoint' => '/ready',
                                           'invocation_timeout' => 10,
                                           'interval' => 7
                                         }
                                       },
                                       'metadata' => {
                                         'labels' => {
                                           'release' => 'stable',
                                           'seriouseats.com/potato' => 'mashed'
                                         },
                                         'annotations' => { 'checksum' => 'SHA' }
                                       }
                                     }
                                   })
    end
  end

  describe 'POST /v3/apps/:guid/processes/:type/actions/scale' do
    let!(:process) do
      VCAP::CloudController::ProcessModel.make(
        :process,
        app: app_model,
        type: 'web',
        instances: 2,
        memory: 1024,
        disk_quota: 1024,
        log_rate_limit: 1_048_576,
        command: 'rackup',
        state: 'STARTED'
      )
    end

    let(:scale_request) do
      {
        instances: 5,
        memory_in_mb: 10,
        disk_in_mb: 20,
        log_rate_limit_in_bytes_per_second: 40
      }
    end

    let(:expected_response) do
      {
        'guid' => process.guid,
        'type' => 'web',

        'relationships' => {
          'app' => { 'data' => { 'guid' => app_model.guid } },
          'revision' => nil
        },
        'command' => 'rackup',
        'user' => 'vcap',
        'instances' => 5,
        'memory_in_mb' => 10,
        'disk_in_mb' => 20,
        'log_rate_limit_in_bytes_per_second' => 40,
        'health_check' => {
          'type' => 'port',
          'data' => {
            'timeout' => nil,
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'readiness_health_check' => {
          'type' => 'process',
          'data' => {
            'invocation_timeout' => nil,
            'interval' => nil
          }
        },
        'metadata' => { 'annotations' => {}, 'labels' => {} },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'version' => process.version,
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}" },
          'scale' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/actions/scale", 'method' => 'POST' },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
          'stats' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/stats" },
          'process_instances' => { 'href' => "#{link_prefix}/v3/processes/#{process.guid}/process_instances" }
        }
      }
    end

    it 'scales the process belonging to an app' do
      post "/v3/apps/#{app_model.guid}/processes/web/actions/scale", scale_request.to_json, developer_headers
      parsed_response = Oj.load(last_response.body)

      expect(last_response.status).to eq(202)
      expect(parsed_response).to be_a_response_like(expected_response)

      process.reload
      expect(process.instances).to eq(5)
      expect(process.memory).to eq(10)
      expect(process.disk_quota).to eq(20)
      expect(process.log_rate_limit).to eq(40)

      events = VCAP::CloudController::Event.where(actor: developer.guid).all

      process_event = events.find { |e| e.type == 'audit.app.process.scale' }
      expect(process_event.values).to include({
                                                type: 'audit.app.process.scale',
                                                actee: app_model.guid,
                                                actee_type: 'app',
                                                actee_name: 'my_app',
                                                actor: developer.guid,
                                                actor_type: 'user',
                                                actor_username: user_name,
                                                space_guid: space.guid,
                                                organization_guid: space.organization.guid
                                              })
      expect(process_event.metadata).to eq({
                                             'process_guid' => process.guid,
                                             'process_type' => 'web',
                                             'request' => {
                                               'instances' => 5,
                                               'memory_in_mb' => 10,
                                               'disk_in_mb' => 20,
                                               'log_rate_limit_in_bytes_per_second' => 40
                                             }
                                           })
    end

    context 'when the log rate limit would be exceeded by adding additional instances' do
      let(:scale_request) do
        {
          instances: 5
        }
      end

      before do
        org.update(quota_definition: VCAP::CloudController::QuotaDefinition.make(log_rate_limit: 2_097_152))
      end

      it 'fails to scale the process' do
        post "/v3/apps/#{app_model.guid}/processes/web/actions/scale", scale_request.to_json, developer_headers

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors'][0]['detail']).to eq 'log_rate_limit exceeds organization log rate quota'

        process.reload
        expect(process.instances).to eq(2)
      end
    end

    context 'when the user is assigned the space_supporter role' do
      let(:space_supporter) do
        user = VCAP::CloudController::User.make
        org.add_user(user)
        space.add_supporter(user)
        user
      end

      it 'can scale a process' do
        post "/v3/apps/#{app_model.guid}/processes/web/actions/scale", scale_request.to_json, headers_for(space_supporter)

        expect(last_response.status).to eq(202)
        expect(parsed_response).to be_a_response_like(expected_response)

        process.reload
        expect(process.instances).to eq(5)
        expect(process.memory).to eq(10)
        expect(process.disk_quota).to eq(20)
        expect(process.log_rate_limit).to eq(40)
      end
    end

    context 'telemetry' do
      it 'logs the required fields when the process gets scaled' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'scale-app' => {
              'api-version' => 'v3',
              'instance-count' => 5,
              'memory-in-mb' => 10,
              'disk-in-mb' => 20,
              'log-rate-in-bytes-per-second' => 40,
              'process-type' => 'web',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(developer.guid)
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))

          post "/v3/apps/#{app_model.guid}/processes/web/actions/scale", scale_request.to_json, developer_headers

          expect(last_response.status).to eq(202), last_response.body
        end
      end
    end
  end

  describe 'DELETE /v3/apps/:guid/processes/:type/instances/:index' do
    before do
      allow_any_instance_of(VCAP::CloudController::Diego::BbsAppsClient).to receive(:stop_index)
    end

    let!(:process) { VCAP::CloudController::ProcessModel.make(:process, type: 'web', app: app_model) }

    it 'terminates a single instance of a process belonging to an app' do
      delete "/v3/apps/#{app_model.guid}/processes/web/instances/0", nil, developer_headers

      expect(last_response.status).to eq(204)

      events        = VCAP::CloudController::Event.where(actor: developer.guid).all
      process_event = events.find { |e| e.type == 'audit.app.process.terminate_instance' }
      expect(process_event.values).to include({
                                                type: 'audit.app.process.terminate_instance',
                                                actee: app_model.guid,
                                                actee_type: 'app',
                                                actee_name: 'my_app',
                                                actor: developer.guid,
                                                actor_type: 'user',
                                                actor_username: user_name,
                                                space_guid: space.guid,
                                                organization_guid: space.organization.guid
                                              })
      expect(process_event.metadata).to eq({
                                             'process_guid' => process.guid,
                                             'process_type' => 'web',
                                             'process_index' => 0
                                           })
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { delete "/v3/apps/#{app_model.guid}/processes/web/instances/0", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403 }.freeze)
        h['admin'] = { code: 204 }
        h['space_developer'] = { code: 204 }
        h['space_supporter'] = { code: 204 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end
end
