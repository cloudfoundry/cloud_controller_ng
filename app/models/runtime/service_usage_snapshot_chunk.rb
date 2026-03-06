module VCAP::CloudController
  class ServiceUsageSnapshotChunk < Sequel::Model(:service_usage_snapshot_chunks)
    plugin :serialization

    many_to_one :service_usage_snapshot

    serialize_attributes :json, :service_instances

    def validate
      super
      validates_presence :service_usage_snapshot_id
      validates_presence :organization_guid
      validates_presence :space_guid
      validates_presence :chunk_index
    end
  end
end
