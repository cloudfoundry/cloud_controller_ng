# Creates tables for service usage snapshots feature.
#
# Service usage snapshots capture a point-in-time baseline of all service instances
# (both managed and user-provided) with a checkpoint in the service usage event stream.
# This mirrors the app usage snapshots feature for service billing systems.
#
# Each snapshot consists of:
# - A parent record with summary counts and checkpoint reference
# - Chunk records containing up to 50 service instances each for bounded memory/API sizes

Sequel.migration do
  up do
    create_table :service_usage_snapshots do
      primary_key :id, type: :Bignum, name: :id
      String :guid, null: false, size: 255
      String :checkpoint_event_guid, null: true, size: 255
      Timestamp :checkpoint_event_created_at, null: true
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :completed_at, null: true
      Integer :service_instance_count, null: false, default: 0
      Integer :organization_count, null: false, default: 0
      Integer :space_count, null: false, default: 0
      Integer :chunk_count, null: false, default: 0

      index :guid, unique: true, name: :service_usage_snapshots_guid_index
      index :created_at, name: :service_usage_snapshots_created_at_index
      index :completed_at, name: :service_usage_snapshots_completed_at_index
      index :checkpoint_event_guid, name: :service_usage_snapshots_checkpoint_event_guid_index
    end

    create_table :service_usage_snapshot_chunks do
      primary_key :id, type: :Bignum, name: :id
      column :service_usage_snapshot_id, :Bignum, null: false
      String :organization_guid, null: false, size: 255
      String :organization_name, null: true, size: 255
      String :space_guid, null: false, size: 255
      String :space_name, null: true, size: 255
      Integer :chunk_index, null: false, default: 0
      Text :service_instances, null: true

      index %i[service_usage_snapshot_id space_guid chunk_index],
            name: :svc_snapshot_chunks_space_idx,
            unique: true
      foreign_key [:service_usage_snapshot_id], :service_usage_snapshots,
                  name: :fk_svc_snapshot_chunk_snapshot_id,
                  on_delete: :cascade
    end
  end

  down do
    drop_table :service_usage_snapshot_chunks
    drop_table :service_usage_snapshots
  end
end
