module Fog
  module Google
    class Compute
      class Snapshot < Fog::Model
        identity :name

        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description
        attribute :disk_size_gb, :aliases => "diskSizeGb"
        attribute :id
        attribute :kind
        attribute :label_fingerprint, :aliases => "labelFingerprint"
        attribute :labels
        attribute :licenses
        attribute :self_link, :aliases => "selfLink"
        attribute :snapshot_encryption_key, :aliases => "snapshotEncryptionKey"
        attribute :source_disk, :aliases => "sourceDisk"
        attribute :source_disk_encryption_key, :aliases => "sourceDiskEncryptionKey"
        attribute :source_disk_id, :aliases => "sourceDiskId"
        attribute :status
        attribute :storage_bytes, :aliases => "storageBytes"
        attribute :storage_bytes_status, :aliases => "storageBytesStatus"

        CREATING_STATE  = "CREATING".freeze
        DELETING_STATE  = "DELETING".freeze
        FAILED_STATE    = "FAILED".freeze
        READY_STATE     = "READY".freeze
        UPLOADING_STATE = "UPLOADING".freeze

        def destroy(async = true)
          requires :identity

          data = service.delete_snapshot(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def set_labels(new_labels)
          requires :identity, :label_fingerprint

          unless new_labels.is_a? Hash
            raise ArgumentError,
                  "Labels should be a hash, e.g. {foo: \"bar\",fog: \"test\"}"
          end

          service.set_snapshot_labels(identity, label_fingerprint, new_labels)
          reload
        end

        def ready?
          status == READY_STATE
        end

        def resource_url
          "#{service.project}/global/snapshots/#{name}"
        end
      end
    end
  end
end
