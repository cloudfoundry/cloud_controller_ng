require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'App Usage Snapshots' do
  let(:user) { make_user }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }

  describe 'POST /v3/app_usage/snapshots' do
    let(:api_call) { ->(user_headers) { post '/v3/app_usage/snapshots', nil, user_headers } }

    let(:expected_codes_and_responses) do
      h = Hash.new { |hash, key| hash[key] = { code: 403 } }
      h['admin'] = { code: 202 }
      h
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    context 'when the user is an admin' do
      it 'creates a usage snapshot asynchronously' do
        post '/v3/app_usage/snapshots', nil, admin_header

        expect(last_response.status).to eq(202)
        expect(last_response.headers['Location']).to match(%r{/v3/jobs/})

        job_guid = last_response.headers['Location'].split('/').last
        get "/v3/jobs/#{job_guid}", nil, admin_header

        expect(last_response.status).to eq(200)
        job_response = Oj.load(last_response.body)
        expect(job_response['operation']).to eq('app_usage_snapshot.generate')
      end

      context 'when a snapshot is already in progress' do
        before do
          VCAP::CloudController::AppUsageSnapshot.create(
            guid: 'in-progress-snapshot',
            checkpoint_event_guid: nil,
            created_at: Time.now.utc,
            completed_at: nil,
            instance_count: 0,
            organization_count: 0,
            space_count: 0,
            app_count: 0,
            chunk_count: 0
          )
        end

        it 'returns 409 Conflict' do
          post '/v3/app_usage/snapshots', nil, admin_header

          expect(last_response.status).to eq(409)
          expect(last_response).to have_error_message('An app usage snapshot is already being generated')
        end
      end

      context 'when previous snapshots exist but are all completed' do
        before do
          # Create several completed snapshots
          3.times do |i|
            VCAP::CloudController::AppUsageSnapshot.create(
              guid: "completed-snapshot-#{i}",
              checkpoint_event_guid: "checkpoint-guid-#{i}",
              created_at: Time.now.utc - (i + 1).hours,
              completed_at: Time.now.utc - i.hours,
              instance_count: 10,
              organization_count: 2,
              space_count: 3,
              app_count: 5,
              chunk_count: 1
            )
          end
        end

        it 'allows creating a new snapshot' do
          post '/v3/app_usage/snapshots', nil, admin_header

          expect(last_response.status).to eq(202)
          expect(last_response.headers['Location']).to match(%r{/v3/jobs/})
        end
      end

      context 'when a previously in-progress snapshot has been cleaned up' do
        it 'allows creating a new snapshot' do
          post '/v3/app_usage/snapshots', nil, admin_header

          expect(last_response.status).to eq(202)
        end
      end

      context 'when there are no running processes (empty foundation)' do
        it 'creates a snapshot with zero counts' do
          post '/v3/app_usage/snapshots', nil, admin_header

          expect(last_response.status).to eq(202)

          # Execute the job synchronously
          job_guid = last_response.headers['Location'].split('/').last
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          # Check job completed
          get "/v3/jobs/#{job_guid}", nil, admin_header
          expect(last_response.status).to eq(200)
          job_response = Oj.load(last_response.body)
          expect(job_response['state']).to eq('COMPLETE')

          # Get snapshot and verify zero counts
          snapshot_guid = VCAP::CloudController::AppUsageSnapshot.last.guid
          get "/v3/app_usage/snapshots/#{snapshot_guid}", nil, admin_header
          expect(last_response.status).to eq(200)

          snapshot_response = Oj.load(last_response.body)
          expect(snapshot_response['summary']['instance_count']).to eq(0)
          expect(snapshot_response['summary']['app_count']).to eq(0)
          expect(snapshot_response['summary']['organization_count']).to eq(0)
          expect(snapshot_response['summary']['space_count']).to eq(0)
          expect(snapshot_response['summary']['chunk_count']).to eq(0)
          expect(snapshot_response['completed_at']).not_to be_nil
        end
      end
    end

    context 'when the user is not an admin' do
      let(:user_header) { headers_for(user) }

      it 'returns 403 Forbidden' do
        post '/v3/app_usage/snapshots', nil, user_header

        expect(last_response.status).to eq(403)
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 Unauthorized' do
        post '/v3/app_usage/snapshots', nil, base_json_headers

        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'GET /v3/app_usage/snapshots/:guid' do
    let!(:snapshot) do
      VCAP::CloudController::AppUsageSnapshot.create(
        guid: 'test-snapshot-guid',
        checkpoint_event_guid: 'checkpoint-event-guid-12345',
        checkpoint_event_created_at: Time.now.utc - 1.hour,
        created_at: Time.now.utc - 1.hour,
        completed_at: Time.now.utc - 59.minutes,
        instance_count: 10,
        organization_count: 2,
        space_count: 3,
        app_count: 5,
        chunk_count: 3
      )
    end

    let(:api_call) { ->(user_headers) { get "/v3/app_usage/snapshots/#{snapshot.guid}", nil, user_headers } }

    let(:snapshot_json) do
      {
        guid: snapshot.guid,
        created_at: iso8601,
        completed_at: iso8601,
        checkpoint_event_guid: 'checkpoint-event-guid-12345',
        checkpoint_event_created_at: iso8601,
        summary: {
          instance_count: 10,
          app_count: 5,
          organization_count: 2,
          space_count: 3,
          chunk_count: 3
        },
        links: {
          self: { href: /#{Regexp.escape("/v3/app_usage/snapshots/#{snapshot.guid}")}/ },
          checkpoint_event: { href: %r{/v3/app_usage_events/checkpoint-event-guid-12345} },
          chunks: { href: /#{Regexp.escape("/v3/app_usage/snapshots/#{snapshot.guid}/chunks")}/ }
        }
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new { |hash, key| hash[key] = { code: 404 } }
      h['admin'] = { code: 200, response_object: snapshot_json }
      h['admin_read_only'] = { code: 200, response_object: snapshot_json }
      h['global_auditor'] = { code: 200, response_object: snapshot_json }
      h
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    context 'when the snapshot does not exist' do
      it 'returns 404' do
        get '/v3/app_usage/snapshots/does-not-exist', nil, admin_header

        expect(last_response.status).to eq(404)
        expect(last_response).to have_error_message('App usage snapshot not found')
      end
    end
  end

  describe 'GET /v3/app_usage/snapshots' do
    let!(:snapshot1) do
      VCAP::CloudController::AppUsageSnapshot.create(
        guid: 'snapshot-1',
        checkpoint_event_guid: 'checkpoint-guid-100',
        checkpoint_event_created_at: Time.now.utc - 2.hours,
        created_at: Time.now.utc - 2.hours,
        completed_at: Time.now.utc - 119.minutes,
        instance_count: 5,
        organization_count: 1,
        space_count: 1,
        app_count: 2,
        chunk_count: 1
      )
    end

    let!(:snapshot2) do
      VCAP::CloudController::AppUsageSnapshot.create(
        guid: 'snapshot-2',
        checkpoint_event_guid: 'checkpoint-guid-200',
        checkpoint_event_created_at: Time.now.utc - 1.hour,
        created_at: Time.now.utc - 59.minutes,
        completed_at: Time.now.utc - 59.minutes,
        instance_count: 10,
        organization_count: 2,
        space_count: 2,
        app_count: 4,
        chunk_count: 2
      )
    end

    let(:api_call) { ->(user_headers) { get '/v3/app_usage/snapshots', nil, user_headers } }

    let(:expected_codes_and_responses) do
      h = Hash.new { |hash, key| hash[key] = { code: 200, response_objects: [] } }
      h['admin'] = { code: 200, response_objects: [hash_including(guid: 'snapshot-1'), hash_including(guid: 'snapshot-2')] }
      h['admin_read_only'] = { code: 200, response_objects: [hash_including(guid: 'snapshot-1'), hash_including(guid: 'snapshot-2')] }
      h['global_auditor'] = { code: 200, response_objects: [hash_including(guid: 'snapshot-1'), hash_including(guid: 'snapshot-2')] }
      h
    end

    it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

    context 'when the user is an admin' do
      it 'returns all snapshots' do
        get '/v3/app_usage/snapshots', nil, admin_header

        expect(last_response.status).to eq(200)
        response = Oj.load(last_response.body)
        expect(response['resources'].length).to eq(2)
        expect(response['resources'].pluck('guid')).to contain_exactly('snapshot-1', 'snapshot-2')
      end

      it 'supports pagination' do
        get '/v3/app_usage/snapshots?per_page=1', nil, admin_header

        expect(last_response.status).to eq(200)
        response = Oj.load(last_response.body)
        expect(response['resources'].length).to eq(1)
        expect(response['pagination']['total_results']).to eq(2)
      end
    end
  end

  describe 'GET /v3/app_usage/snapshots/:guid/chunks' do
    let!(:snapshot) do
      VCAP::CloudController::AppUsageSnapshot.create(
        guid: 'test-snapshot-guid',
        checkpoint_event_guid: 'checkpoint-event-guid-12345',
        checkpoint_event_created_at: Time.now.utc - 1.hour,
        created_at: Time.now.utc - 1.hour,
        completed_at: Time.now.utc - 59.minutes,
        instance_count: 15,
        organization_count: 2,
        space_count: 2,
        app_count: 4,
        chunk_count: 2
      )
    end

    let!(:chunk1) do
      VCAP::CloudController::AppUsageSnapshotChunk.create(
        app_usage_snapshot_id: snapshot.id,
        organization_guid: 'org-1-guid',
        organization_name: 'org-1-name',
        space_guid: 'space-1-guid',
        space_name: 'space-1-name',
        chunk_index: 0,
        processes: [
          { 'app_guid' => 'app-1-guid', 'app_name' => 'app-1', 'process_guid' => 'process-1-guid',
            'process_type' => 'web', 'instance_count' => 5, 'memory_in_mb_per_instance' => 256,
            'buildpack_guid' => 'bp-guid', 'buildpack_name' => 'ruby_buildpack' },
          { 'app_guid' => 'app-1-guid', 'app_name' => 'app-1', 'process_guid' => 'process-2-guid',
            'process_type' => 'worker', 'instance_count' => 5, 'memory_in_mb_per_instance' => 512,
            'buildpack_guid' => 'bp-guid', 'buildpack_name' => 'ruby_buildpack' }
        ]
      )
    end

    let!(:chunk2) do
      VCAP::CloudController::AppUsageSnapshotChunk.create(
        app_usage_snapshot_id: snapshot.id,
        organization_guid: 'org-2-guid',
        organization_name: 'org-2-name',
        space_guid: 'space-2-guid',
        space_name: 'space-2-name',
        chunk_index: 0,
        processes: [
          { 'app_guid' => 'app-2-guid', 'app_name' => 'app-2', 'process_guid' => 'process-3-guid',
            'process_type' => 'web', 'instance_count' => 5, 'memory_in_mb_per_instance' => 1024,
            'buildpack_guid' => nil, 'buildpack_name' => nil }
        ]
      )
    end

    context 'when the user is an admin' do
      it 'returns the chunk details for the snapshot' do
        get "/v3/app_usage/snapshots/#{snapshot.guid}/chunks", nil, admin_header

        expect(last_response.status).to eq(200)
        response = Oj.load(last_response.body)
        expect(response['resources'].length).to eq(2)
        expect(response['resources'].pluck('space_guid')).to contain_exactly('space-1-guid', 'space-2-guid')
      end

      it 'includes process details with V3-aligned fields in each chunk record' do
        get "/v3/app_usage/snapshots/#{snapshot.guid}/chunks", nil, admin_header

        expect(last_response.status).to eq(200)
        response = Oj.load(last_response.body)
        chunk1_response = response['resources'].find { |r| r['space_guid'] == 'space-1-guid' }

        expect(chunk1_response['organization_guid']).to eq('org-1-guid')
        expect(chunk1_response['organization_name']).to eq('org-1-name')
        expect(chunk1_response['space_name']).to eq('space-1-name')
        expect(chunk1_response['chunk_index']).to eq(0)
        expect(chunk1_response['processes'].length).to eq(2)

        process = chunk1_response['processes'].first
        expect(process).to include(
          'app_guid' => 'app-1-guid',
          'app_name' => 'app-1',
          'process_guid' => 'process-1-guid',
          'process_type' => 'web',
          'instance_count' => 5,
          'memory_in_mb_per_instance' => 256,
          'buildpack_guid' => 'bp-guid',
          'buildpack_name' => 'ruby_buildpack'
        )
      end

      it 'supports pagination' do
        get "/v3/app_usage/snapshots/#{snapshot.guid}/chunks?per_page=1", nil, admin_header

        expect(last_response.status).to eq(200)
        response = Oj.load(last_response.body)
        expect(response['resources'].length).to eq(1)
        expect(response['pagination']['total_results']).to eq(2)
      end
    end

    context 'when the snapshot is still processing' do
      let!(:processing_snapshot) do
        VCAP::CloudController::AppUsageSnapshot.create(
          guid: 'processing-snapshot-guid',
          checkpoint_event_guid: nil,
          created_at: Time.now.utc,
          completed_at: nil,
          instance_count: 0,
          organization_count: 0,
          space_count: 0,
          app_count: 0,
          chunk_count: 0
        )
      end

      it 'returns 422 Unprocessable Entity' do
        get "/v3/app_usage/snapshots/#{processing_snapshot.guid}/chunks", nil, admin_header

        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Snapshot is still processing')
      end
    end

    context 'when the snapshot does not exist' do
      it 'returns 404' do
        get '/v3/app_usage/snapshots/does-not-exist/chunks', nil, admin_header

        expect(last_response.status).to eq(404)
        expect(last_response).to have_error_message('App usage snapshot not found')
      end
    end

    context 'when the user is not an admin' do
      let(:user_header) { headers_for(user) }

      it 'returns 404' do
        get "/v3/app_usage/snapshots/#{snapshot.guid}/chunks", nil, user_header

        expect(last_response.status).to eq(404)
      end
    end
  end
end
