module VCAP::CloudController
  class ServiceUsageSnapshot < Sequel::Model(:service_usage_snapshots)
    one_to_many :service_usage_snapshot_chunks

    def validate
      super
      # NOTE: checkpoint_event_guid and checkpoint_event_created_at can be NULL when
      # the snapshot is first created (placeholder) or when there are no usage events
      # (empty system). The columns are intentionally nullable in the migration.
      validates_presence :created_at
      validates_presence :service_instance_count
      validates_presence :organization_count
      validates_presence :space_count
      validates_presence :chunk_count
    end

    def processing?
      completed_at.nil?
    end

    def complete?
      !completed_at.nil?
    end
  end
end
