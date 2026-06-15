require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceUsageSnapshot do
    describe 'associations' do
      it 'has many service_usage_snapshot_chunks' do
        snapshot = ServiceUsageSnapshot.make
        chunk1 = ServiceUsageSnapshotChunk.make(service_usage_snapshot: snapshot, space_guid: 'space-1', chunk_index: 0)
        chunk2 = ServiceUsageSnapshotChunk.make(service_usage_snapshot: snapshot, space_guid: 'space-2', chunk_index: 0)

        expect(snapshot.service_usage_snapshot_chunks).to contain_exactly(chunk1, chunk2)
      end
    end

    describe 'validations' do
      it 'allows nil checkpoint_event_guid (for placeholder snapshots)' do
        snapshot = ServiceUsageSnapshot.make
        snapshot.checkpoint_event_guid = nil
        expect(snapshot).to be_valid
      end

      it 'validates presence of created_at' do
        snapshot = ServiceUsageSnapshot.new(
          guid: SecureRandom.uuid,
          service_instance_count: 0,
          organization_count: 0,
          space_count: 0,
          chunk_count: 0
        )
        snapshot.created_at = nil
        snapshot.validate
        expect(snapshot.errors.on(:created_at)).to eq([:presence])
      end

      it 'validates presence of chunk_count' do
        snapshot = ServiceUsageSnapshot.new(
          guid: SecureRandom.uuid,
          created_at: Time.now.utc,
          service_instance_count: 0,
          organization_count: 0,
          space_count: 0
        )
        snapshot.chunk_count = nil
        snapshot.validate
        expect(snapshot.errors.on(:chunk_count)).to eq([:presence])
      end
    end

    describe '#processing?' do
      it 'returns true when completed_at is nil' do
        snapshot = ServiceUsageSnapshot.make
        snapshot.completed_at = nil
        expect(snapshot.processing?).to be true
      end

      it 'returns false when completed_at is set' do
        snapshot = ServiceUsageSnapshot.make
        snapshot.completed_at = Time.now.utc
        expect(snapshot.processing?).to be false
      end
    end

    describe '#complete?' do
      it 'returns false when completed_at is nil' do
        snapshot = ServiceUsageSnapshot.make
        snapshot.completed_at = nil
        expect(snapshot.complete?).to be false
      end

      it 'returns true when completed_at is set' do
        snapshot = ServiceUsageSnapshot.make
        snapshot.completed_at = Time.now.utc
        expect(snapshot.complete?).to be true
      end
    end
  end
end
