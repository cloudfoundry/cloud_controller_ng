require 'spec_helper'

RSpec.describe 'Service Usage Snapshots' do
  let(:user) { make_user }
  let(:admin_header) { admin_headers_for(user) }

  describe 'POST /v3/service_usage/snapshots' do
    it 'creates a snapshot generation job and returns 202' do
      post '/v3/service_usage/snapshots', nil, admin_header

      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to match(%r{/v3/jobs/})
    end

    it 'requires admin permissions' do
      post '/v3/service_usage/snapshots', nil, headers_for(user)

      expect(last_response.status).to eq(403)
    end

    context 'when a snapshot is already in progress' do
      before do
        VCAP::CloudController::ServiceUsageSnapshot.make(completed_at: nil)
      end

      it 'returns 409 conflict' do
        post '/v3/service_usage/snapshots', nil, admin_header

        expect(last_response.status).to eq(409)
        expect(parsed_response['errors'].first['title']).to match(/ServiceUsageSnapshotGenerationInProgress/)
      end
    end

    context 'when previous snapshots exist but are all completed' do
      before do
        # Create several completed snapshots
        3.times do
          VCAP::CloudController::ServiceUsageSnapshot.make(completed_at: Time.now.utc)
        end
      end

      it 'allows creating a new snapshot' do
        post '/v3/service_usage/snapshots', nil, admin_header

        expect(last_response.status).to eq(202)
        expect(last_response.headers['Location']).to match(%r{/v3/jobs/})
      end
    end

    context 'when a previously in-progress snapshot has been cleaned up' do
      it 'allows creating a new snapshot' do
        post '/v3/service_usage/snapshots', nil, admin_header

        expect(last_response.status).to eq(202)
      end
    end

    context 'when there are no service instances (empty foundation)' do
      it 'creates a snapshot with zero counts' do
        post '/v3/service_usage/snapshots', nil, admin_header

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
        snapshot_guid = VCAP::CloudController::ServiceUsageSnapshot.last.guid
        get "/v3/service_usage/snapshots/#{snapshot_guid}", nil, admin_header
        expect(last_response.status).to eq(200)

        snapshot_response = Oj.load(last_response.body)
        expect(snapshot_response['summary']['service_instance_count']).to eq(0)
        expect(snapshot_response['summary']['organization_count']).to eq(0)
        expect(snapshot_response['summary']['space_count']).to eq(0)
        expect(snapshot_response['summary']['chunk_count']).to eq(0)
        expect(snapshot_response['completed_at']).not_to be_nil
      end
    end
  end

  describe 'GET /v3/service_usage/snapshots/:guid' do
    let(:snapshot) { VCAP::CloudController::ServiceUsageSnapshot.make(service_instance_count: 10, completed_at: Time.now.utc) }

    it 'returns the snapshot' do
      get "/v3/service_usage/snapshots/#{snapshot.guid}", nil, admin_header

      expect(last_response.status).to eq(200)
      expect(parsed_response['guid']).to eq(snapshot.guid)
      expect(parsed_response['summary']['service_instance_count']).to eq(10)
    end

    it 'returns 404 for non-admin users' do
      get "/v3/service_usage/snapshots/#{snapshot.guid}", nil, headers_for(user)

      expect(last_response.status).to eq(404)
    end

    it 'returns 404 for non-existent snapshot' do
      get '/v3/service_usage/snapshots/nonexistent-guid', nil, admin_header

      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /v3/service_usage/snapshots' do
    let!(:snapshot1) { VCAP::CloudController::ServiceUsageSnapshot.make(service_instance_count: 5, completed_at: Time.now.utc) }
    let!(:snapshot2) { VCAP::CloudController::ServiceUsageSnapshot.make(service_instance_count: 10, completed_at: Time.now.utc) }

    it 'lists all snapshots' do
      get '/v3/service_usage/snapshots', nil, admin_header

      expect(last_response.status).to eq(200)
      expect(parsed_response['pagination']['total_results']).to eq(2)
      expect(parsed_response['resources'].pluck('guid')).to contain_exactly(snapshot1.guid, snapshot2.guid)
    end

    it 'returns empty list for non-admin users' do
      get '/v3/service_usage/snapshots', nil, headers_for(user)

      expect(last_response.status).to eq(200)
      expect(parsed_response['pagination']['total_results']).to eq(0)
    end

    it 'supports pagination' do
      get '/v3/service_usage/snapshots?per_page=1', nil, admin_header

      expect(last_response.status).to eq(200)
      expect(parsed_response['pagination']['total_results']).to eq(2)
      expect(parsed_response['resources'].length).to eq(1)
    end
  end

  describe 'GET /v3/service_usage/snapshots/:guid/chunks' do
    let!(:snapshot) do
      VCAP::CloudController::ServiceUsageSnapshot.create(
        guid: 'test-service-snapshot-guid',
        checkpoint_event_guid: 'checkpoint-event-guid-12345',
        checkpoint_event_created_at: Time.now.utc - 1.hour,
        created_at: Time.now.utc - 1.hour,
        completed_at: Time.now.utc - 59.minutes,
        service_instance_count: 5,
        organization_count: 2,
        space_count: 2,
        chunk_count: 2
      )
    end

    let!(:chunk1) do
      VCAP::CloudController::ServiceUsageSnapshotChunk.create(
        service_usage_snapshot_id: snapshot.id,
        organization_guid: 'org-1-guid',
        organization_name: 'org-1-name',
        space_guid: 'space-1-guid',
        space_name: 'space-1-name',
        chunk_index: 0,
        service_instances: [
          { 'service_instance_guid' => 'si-1', 'service_instance_name' => 'my-db', 'service_instance_type' => 'managed',
            'service_plan_guid' => 'plan-1', 'service_plan_name' => 'standard',
            'service_offering_guid' => 'svc-1', 'service_offering_name' => 'mysql',
            'service_broker_guid' => 'broker-1', 'service_broker_name' => 'my-broker' },
          { 'service_instance_guid' => 'si-2', 'service_instance_name' => 'my-cache', 'service_instance_type' => 'managed',
            'service_plan_guid' => 'plan-2', 'service_plan_name' => 'premium',
            'service_offering_guid' => 'svc-2', 'service_offering_name' => 'redis',
            'service_broker_guid' => 'broker-1', 'service_broker_name' => 'my-broker' },
          { 'service_instance_guid' => 'si-3', 'service_instance_name' => 'my-creds', 'service_instance_type' => 'user_provided',
            'service_plan_guid' => nil, 'service_plan_name' => nil,
            'service_offering_guid' => nil, 'service_offering_name' => nil,
            'service_broker_guid' => nil, 'service_broker_name' => nil }
        ]
      )
    end

    let!(:chunk2) do
      VCAP::CloudController::ServiceUsageSnapshotChunk.create(
        service_usage_snapshot_id: snapshot.id,
        organization_guid: 'org-2-guid',
        organization_name: 'org-2-name',
        space_guid: 'space-2-guid',
        space_name: 'space-2-name',
        chunk_index: 0,
        service_instances: [
          { 'service_instance_guid' => 'si-4', 'service_instance_name' => 'other-db', 'service_instance_type' => 'managed',
            'service_plan_guid' => 'plan-3', 'service_plan_name' => 'enterprise',
            'service_offering_guid' => 'svc-1', 'service_offering_name' => 'mysql',
            'service_broker_guid' => 'broker-2', 'service_broker_name' => 'other-broker' },
          { 'service_instance_guid' => 'si-5', 'service_instance_name' => 'other-cache', 'service_instance_type' => 'managed',
            'service_plan_guid' => 'plan-4', 'service_plan_name' => 'basic',
            'service_offering_guid' => 'svc-2', 'service_offering_name' => 'redis',
            'service_broker_guid' => 'broker-2', 'service_broker_name' => 'other-broker' }
        ]
      )
    end

    context 'when the user is an admin' do
      it 'returns the chunk details for the snapshot' do
        get "/v3/service_usage/snapshots/#{snapshot.guid}/chunks", nil, admin_header

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].length).to eq(2)
        expect(parsed_response['resources'].pluck('space_guid')).to contain_exactly('space-1-guid', 'space-2-guid')
      end

      it 'includes service instance details with V3-aligned fields in each chunk record' do
        get "/v3/service_usage/snapshots/#{snapshot.guid}/chunks", nil, admin_header

        expect(last_response.status).to eq(200)
        chunk1_response = parsed_response['resources'].find { |r| r['space_guid'] == 'space-1-guid' }

        expect(chunk1_response['organization_guid']).to eq('org-1-guid')
        expect(chunk1_response['organization_name']).to eq('org-1-name')
        expect(chunk1_response['space_name']).to eq('space-1-name')
        expect(chunk1_response['chunk_index']).to eq(0)
        expect(chunk1_response['service_instances'].length).to eq(3)

        managed_instance = chunk1_response['service_instances'].first
        expect(managed_instance).to include(
          'service_instance_guid' => 'si-1',
          'service_instance_name' => 'my-db',
          'service_instance_type' => 'managed',
          'service_plan_guid' => 'plan-1',
          'service_plan_name' => 'standard',
          'service_offering_guid' => 'svc-1',
          'service_offering_name' => 'mysql',
          'service_broker_guid' => 'broker-1',
          'service_broker_name' => 'my-broker'
        )

        user_provided = chunk1_response['service_instances'].last
        expect(user_provided).to include(
          'service_instance_type' => 'user_provided',
          'service_plan_guid' => nil,
          'service_broker_guid' => nil
        )
      end

      it 'supports pagination' do
        get "/v3/service_usage/snapshots/#{snapshot.guid}/chunks?per_page=1", nil, admin_header

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].length).to eq(1)
        expect(parsed_response['pagination']['total_results']).to eq(2)
      end
    end

    context 'when the snapshot is still processing' do
      let!(:processing_snapshot) do
        VCAP::CloudController::ServiceUsageSnapshot.create(
          guid: 'processing-service-snapshot-guid',
          checkpoint_event_guid: nil,
          created_at: Time.now.utc,
          completed_at: nil,
          service_instance_count: 0,
          organization_count: 0,
          space_count: 0,
          chunk_count: 0
        )
      end

      it 'returns 422 Unprocessable Entity' do
        get "/v3/service_usage/snapshots/#{processing_snapshot.guid}/chunks", nil, admin_header

        expect(last_response.status).to eq(422)
      end
    end

    context 'when the snapshot does not exist' do
      it 'returns 404' do
        get '/v3/service_usage/snapshots/does-not-exist/chunks', nil, admin_header

        expect(last_response.status).to eq(404)
      end
    end

    context 'when the user is not an admin' do
      it 'returns 404' do
        get "/v3/service_usage/snapshots/#{snapshot.guid}/chunks", nil, headers_for(user)

        expect(last_response.status).to eq(404)
      end
    end
  end
end
