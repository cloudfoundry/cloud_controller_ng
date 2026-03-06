require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppUsageSnapshotChunk do
    describe 'associations' do
      it 'belongs to app_usage_snapshot' do
        snapshot = AppUsageSnapshot.make
        chunk = AppUsageSnapshotChunk.make(app_usage_snapshot: snapshot)

        expect(chunk.app_usage_snapshot).to eq(snapshot)
      end
    end

    describe 'validations' do
      it 'validates presence of app_usage_snapshot_id' do
        chunk = AppUsageSnapshotChunk.new(
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0
        )
        chunk.validate
        expect(chunk.errors.on(:app_usage_snapshot_id)).to eq([:presence])
      end

      it 'validates presence of organization_guid' do
        snapshot = AppUsageSnapshot.make
        chunk = AppUsageSnapshotChunk.new(
          app_usage_snapshot_id: snapshot.id,
          space_guid: 'space-guid',
          chunk_index: 0
        )
        chunk.validate
        expect(chunk.errors.on(:organization_guid)).to eq([:presence])
      end

      it 'validates presence of space_guid' do
        snapshot = AppUsageSnapshot.make
        chunk = AppUsageSnapshotChunk.new(
          app_usage_snapshot_id: snapshot.id,
          organization_guid: 'org-guid',
          chunk_index: 0
        )
        chunk.validate
        expect(chunk.errors.on(:space_guid)).to eq([:presence])
      end

      it 'validates presence of chunk_index' do
        snapshot = AppUsageSnapshot.make
        chunk = AppUsageSnapshotChunk.new(
          app_usage_snapshot_id: snapshot.id,
          organization_guid: 'org-guid',
          space_guid: 'space-guid'
        )
        chunk.validate
        expect(chunk.errors.on(:chunk_index)).to eq([:presence])
      end
    end

    describe 'processes serialization' do
      it 'serializes and deserializes processes as JSON' do
        snapshot = AppUsageSnapshot.make
        processes = [
          { 'app_guid' => 'app-1', 'process_type' => 'web', 'instances' => 3 },
          { 'app_guid' => 'app-2', 'process_type' => 'worker', 'instances' => 2 }
        ]

        chunk = AppUsageSnapshotChunk.create(
          app_usage_snapshot: snapshot,
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0,
          processes: processes
        )

        chunk.reload
        expect(chunk.processes).to eq(processes)
      end

      it 'handles nil processes (column is nullable)' do
        snapshot = AppUsageSnapshot.make
        chunk = AppUsageSnapshotChunk.create(
          app_usage_snapshot: snapshot,
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0,
          processes: nil
        )

        chunk.reload
        expect(chunk.processes).to be_nil
      end

      it 'handles empty array' do
        snapshot = AppUsageSnapshot.make
        chunk = AppUsageSnapshotChunk.create(
          app_usage_snapshot: snapshot,
          organization_guid: 'org-guid',
          space_guid: 'space-guid',
          chunk_index: 0,
          processes: []
        )

        chunk.reload
        expect(chunk.processes).to eq([])
      end
    end

    describe 'cascade delete' do
      it 'deletes chunk records when snapshot is deleted' do
        snapshot = AppUsageSnapshot.make
        AppUsageSnapshotChunk.make(app_usage_snapshot: snapshot, space_guid: 'space-1', chunk_index: 0)
        AppUsageSnapshotChunk.make(app_usage_snapshot: snapshot, space_guid: 'space-2', chunk_index: 0)

        expect(AppUsageSnapshotChunk.count).to eq(2)

        snapshot.destroy

        expect(AppUsageSnapshotChunk.count).to eq(0)
      end
    end

    describe 'multiple chunks per space' do
      it 'allows multiple chunks for the same space with different chunk_index' do
        snapshot = AppUsageSnapshot.make

        chunk1 = AppUsageSnapshotChunk.make(
          app_usage_snapshot: snapshot,
          space_guid: 'space-1',
          chunk_index: 0
        )

        chunk2 = AppUsageSnapshotChunk.make(
          app_usage_snapshot: snapshot,
          space_guid: 'space-1',
          chunk_index: 1
        )

        expect(snapshot.app_usage_snapshot_chunks.count).to eq(2)
        expect(snapshot.app_usage_snapshot_chunks).to contain_exactly(chunk1, chunk2)
      end
    end
  end
end
