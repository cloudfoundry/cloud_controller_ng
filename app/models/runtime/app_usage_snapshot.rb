module VCAP::CloudController
  class AppUsageSnapshot < Sequel::Model(:app_usage_snapshots)
    one_to_many :app_usage_snapshot_chunks

    def validate
      super
      validates_presence :created_at
      validates_presence :instance_count
      validates_presence :organization_count
      validates_presence :space_count
      validates_presence :app_count
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
