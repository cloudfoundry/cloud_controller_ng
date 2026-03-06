# Creates tables for app usage snapshots feature.
#
# App usage snapshots capture a point-in-time baseline of all running processes
# with a checkpoint in the app usage event stream. This enables non-destructive
# baseline establishment for billing systems.
#
# Each snapshot consists of:
# - A parent record with summary counts and checkpoint reference
# - Chunk records containing up to 50 processes each for bounded memory/API sizes
#
# The chunking strategy ensures:
# - Bounded memory during generation (streaming, not all-in-memory)
# - Bounded API response sizes (each chunk ≤ 50 processes)
# - Atomic operations (snapshot is all-or-nothing via transaction)

Sequel.migration do
  up do
    create_table :app_usage_snapshots do
      primary_key :id, type: :Bignum, name: :id
      String :guid, null: false, size: 255
      String :checkpoint_event_guid, null: true, size: 255
      Timestamp :checkpoint_event_created_at, null: true
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :completed_at, null: true
      Integer :instance_count, null: false, default: 0
      Integer :organization_count, null: false, default: 0
      Integer :space_count, null: false, default: 0
      Integer :chunk_count, null: false, default: 0
      Integer :app_count, null: false, default: 0

      index :guid, unique: true, name: :app_usage_snapshots_guid_index
      index :created_at, name: :app_usage_snapshots_created_at_index
      index :completed_at, name: :app_usage_snapshots_completed_at_index
      index :checkpoint_event_guid, name: :app_usage_snapshots_checkpoint_event_guid_index
    end

    create_table :app_usage_snapshot_chunks do
      primary_key :id, type: :Bignum, name: :id
      column :app_usage_snapshot_id, :Bignum, null: false
      String :organization_guid, null: false, size: 255
      String :organization_name, null: true, size: 255
      String :space_guid, null: false, size: 255
      String :space_name, null: true, size: 255
      Integer :chunk_index, null: false, default: 0
      Text :processes, null: true

      index %i[app_usage_snapshot_id space_guid chunk_index],
            name: :app_snapshot_chunks_space_idx,
            unique: true
      foreign_key [:app_usage_snapshot_id], :app_usage_snapshots,
                  name: :fk_app_snapshot_chunk_snapshot_id,
                  on_delete: :cascade
    end
  end

  down do
    drop_table :app_usage_snapshot_chunks
    drop_table :app_usage_snapshots
  end
end
