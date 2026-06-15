require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceUsageSnapshotChunk do
    describe 'associations' do
      it 'belongs to service_usage_snapshot' do
        snapshot = ServiceUsageSnapshot.make
        chunk = ServiceUsageSnapshotChunk.make(service_usage_snapshot: snapshot)

        expect(chunk.service_usage_snapshot).to eq(snapshot)
      end
    end

    describe 'validations' do
      it 'validates presence of service_usage_snapshot_id' do
        chunk = ServiceUsageSnapshotChunk.new(
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0
        )
        chunk.validate
        expect(chunk.errors.on(:service_usage_snapshot_id)).to eq([:presence])
      end

      it 'validates presence of organization_guid' do
        snapshot = ServiceUsageSnapshot.make
        chunk = ServiceUsageSnapshotChunk.new(
          service_usage_snapshot_id: snapshot.id,
          space_guid: 'space-guid',
          chunk_index: 0
        )
        chunk.validate
        expect(chunk.errors.on(:organization_guid)).to eq([:presence])
      end

      it 'validates presence of space_guid' do
        snapshot = ServiceUsageSnapshot.make
        chunk = ServiceUsageSnapshotChunk.new(
          service_usage_snapshot_id: snapshot.id,
          organization_guid: 'org-guid',
          chunk_index: 0
        )
        chunk.validate
        expect(chunk.errors.on(:space_guid)).to eq([:presence])
      end

      it 'validates presence of chunk_index' do
        snapshot = ServiceUsageSnapshot.make
        chunk = ServiceUsageSnapshotChunk.new(
          service_usage_snapshot_id: snapshot.id,
          organization_guid: 'org-guid',
          space_guid: 'space-guid'
        )
        chunk.validate
        expect(chunk.errors.on(:chunk_index)).to eq([:presence])
      end
    end

    describe 'service_instances serialization' do
      it 'serializes and deserializes service_instances as JSON' do
        snapshot = ServiceUsageSnapshot.make
        service_instances = [
          { 'guid' => 'si-1', 'name' => 'my-db', 'type' => 'managed' },
          { 'guid' => 'si-2', 'name' => 'my-cache', 'type' => 'user_provided' }
        ]

        chunk = ServiceUsageSnapshotChunk.create(
          service_usage_snapshot: snapshot,
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0,
          service_instances: service_instances
        )

        chunk.reload
        expect(chunk.service_instances).to eq(service_instances)
      end

      it 'handles nil service_instances (column is nullable)' do
        snapshot = ServiceUsageSnapshot.make
        chunk = ServiceUsageSnapshotChunk.create(
          service_usage_snapshot: snapshot,
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0,
          service_instances: nil
        )

        chunk.reload
        expect(chunk.service_instances).to be_nil
      end

      it 'handles empty array' do
        snapshot = ServiceUsageSnapshot.make
        chunk = ServiceUsageSnapshotChunk.create(
          service_usage_snapshot: snapshot,
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0,
          service_instances: []
        )

        chunk.reload
        expect(chunk.service_instances).to eq([])
      end
    end

    describe 'cascade delete' do
      it 'deletes chunk records when snapshot is deleted' do
        snapshot = ServiceUsageSnapshot.make
        ServiceUsageSnapshotChunk.make(service_usage_snapshot: snapshot, space_guid: 'space-1', chunk_index: 0)
        ServiceUsageSnapshotChunk.make(service_usage_snapshot: snapshot, space_guid: 'space-2', chunk_index: 0)

        expect(ServiceUsageSnapshotChunk.count).to eq(2)

        snapshot.destroy

        expect(ServiceUsageSnapshotChunk.count).to eq(0)
      end
    end

    describe 'multiple chunks per space' do
      it 'allows multiple chunks for the same space with different chunk_index' do
        snapshot = ServiceUsageSnapshot.make

        chunk1 = ServiceUsageSnapshotChunk.make(
          service_usage_snapshot: snapshot,
          space_guid: 'space-1',
          chunk_index: 0
        )

        chunk2 = ServiceUsageSnapshotChunk.make(
          service_usage_snapshot: snapshot,
          space_guid: 'space-1',
          chunk_index: 1
        )

        expect(snapshot.service_usage_snapshot_chunks.count).to eq(2)
        expect(snapshot.service_usage_snapshot_chunks).to contain_exactly(chunk1, chunk2)
      end
    end
  end
end
