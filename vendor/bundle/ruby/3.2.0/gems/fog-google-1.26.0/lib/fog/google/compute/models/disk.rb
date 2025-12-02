module Fog
  module Google
    class Compute
      class Disk < Fog::Model
        identity :name

        attribute :kind
        attribute :id
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :zone, :aliases => :zone_name
        attribute :status
        attribute :description
        attribute :size_gb, :aliases => "sizeGb"
        attribute :self_link, :aliases => "selfLink"
        attribute :source_image, :aliases => "sourceImage"
        attribute :source_image_id, :aliases => "sourceImageId"
        attribute :source_snapshot, :aliases => "sourceSnapshot"
        attribute :source_snapshot_id, :aliases => "sourceSnapshotId"
        attribute :type
        attribute :labels
        attribute :label_fingerprint, :aliases => "labelFingerprint"
        attribute :users

        def default_description
          if !source_image.nil?
            "created from image: #{source_image}"
          elsif !source_snapshot.nil?
            "created from snapshot: #{source_snapshot}"
          else
            "created with fog"
          end
        end

        def save
          requires :name, :zone, :size_gb

          options = {
            :description => description || default_description,
            :type => type,
            :size_gb => size_gb,
            :source_image => source_image,
            :source_snapshot => source_snapshot,
            :labels => labels
          }.reject { |_, v| v.nil? }

          if options[:source_image]
            unless source_image.include?("projects/")
              options[:source_image] = service.images.get(source_image).self_link
            end
          end

          # Request needs backward compatibility so source image is specified in
          # method arguments
          data = service.insert_disk(name, zone, options[:source_image], **options)
          operation = Fog::Google::Compute::Operations.new(service: service)
                                                      .get(data.name, data.zone)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :name, :zone

          data = service.delete_disk(name, zone_name)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, data.zone)
          operation.wait_for { ready? } unless async
          operation
        end

        def zone_name
          zone.nil? ? nil : zone.split("/")[-1]
        end

        # Returns an attached disk configuration hash.
        #
        # Compute API needs attached disks to be specified in a custom format.
        # This provides a handy shortcut for generating a preformatted config.
        #
        # Example output:
        # {:auto_delete=>false,
        #  :boot=>true,
        #  :mode=>"READ_WRITE",
        #  :source=>"https://www.googleapis.com/compute/v1/projects/myproj/zones/us-central1-f/disks/mydisk",
        #  :type=>"PERSISTENT"}
        #
        # See Instances.insert API docs for more info:
        # https://cloud.google.com/compute/docs/reference/rest/v1/instances/insert
        #
        # @param [Hash]  opts  options to attach the disk with.
        #   @option opts [Boolean]  :writable  The mode in which to attach this
        #     disk. (defaults to READ_WRITE)
        #   @option opts [Boolean]  :boot  Indicates whether this is a boot disk.
        #     (defaults to false)
        #   @option opts [String]  :device_name  Specifies a unique device name
        #     of your choice that is reflected into the /dev/disk/by-id/google-*
        #     tree of a Linux operating system running within the instance.
        #   @option opts [Object]  :encryption_key  Encrypts or decrypts a disk
        #     using a customer-supplied encryption key.
        #   @option opts [Object]  :auto_delete  Specifies whether the disk will
        #     be auto-deleted when the instance is deleted. (defaults to false)
        #
        # @return [Hash] Attached disk configuration hash
        def attached_disk_obj(opts = {})
          requires :self_link
          collection.attached_disk_obj(self_link, **opts)
        end

        # A legacy shorthand for attached_disk_obj
        #
        # @param [Object]  writable  The mode in which to attach this disk.
        #   (defaults to READ_WRITE)
        # @param [Object]  auto_delete  Specifies whether the disk will be
        #   auto-deleted when the instance is deleted. (defaults to false)
        # @return [Hash]
        def get_as_boot_disk(writable = true, auto_delete = false)
          attached_disk_obj(boot: true,
                            writable: writable,
                            auto_delete: auto_delete)
        end

        def ready?
          status == RUNNING_STATE
        end

        def reload
          requires :identity, :zone

          return unless data = begin
            collection.get(identity, zone_name)
          rescue Google::Apis::TransmissionError
            nil
          end

          new_attributes = data.attributes
          merge_attributes(new_attributes)
          self
        end

        def create_snapshot(snapshot_name, snapshot = {})
          requires :name, :zone
          raise ArgumentError, "Invalid snapshot name" unless snapshot_name

          data = service.create_disk_snapshot(snapshot_name, name, zone_name, snapshot)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name, data.zone)
          operation.wait_for { ready? }
          service.snapshots.get(snapshot_name)
        end

        RUNNING_STATE = "READY".freeze
      end
    end
  end
end
