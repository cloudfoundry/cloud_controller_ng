module VCAP::CloudController
  class AppUsageSnapshotChunk < Sequel::Model(:app_usage_snapshot_chunks)
    plugin :serialization

    many_to_one :app_usage_snapshot

    serialize_attributes :json, :processes

    def validate
      super
      validates_presence :app_usage_snapshot_id
      validates_presence :organization_guid
      validates_presence :space_guid
      validates_presence :chunk_index
    end
  end
end
