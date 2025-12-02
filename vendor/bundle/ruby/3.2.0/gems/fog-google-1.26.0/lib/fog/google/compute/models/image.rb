module Fog
  module Google
    class Compute
      class Image < Fog::Model
        identity :name

        attribute :archive_size_bytes, :aliases => "archiveSizeBytes"
        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :deprecated
        attribute :description
        attribute :disk_size_gb, :aliases => "diskSizeGb"
        attribute :family
        attribute :guest_os_features, :aliases => "guestOsFeatures"
        attribute :id
        attribute :image_encryption_key, :aliases => "imageEncryptionKey"
        attribute :kind
        attribute :licenses

        # A RawDisk, e.g. -
        # {
        #   :source         => url_to_gcs_file,
        #   :container_type => 'TAR',
        #   :sha1Checksum   => ,
        # }
        attribute :raw_disk, :aliases => "rawDisk"

        attribute :self_link, :aliases => "selfLink"
        attribute :source_disk, :aliases => "sourceDisk"
        attribute :source_disk_encryption_key, :aliases => "sourceDiskEncryptionKey"
        attribute :source_disk_id, :aliases => "sourceDiskId"
        attribute :source_image, :aliases => "sourceImage"
        attribute :source_image_encryption_key, :aliases => "sourceImageEncryptionKey"
        attribute :source_image_id, :aliases => "sourceImageId"
        attribute :source_type, :aliases => "sourceType"
        attribute :status

        # This attribute is not available in the representation of an
        # 'image' returned by the GCE server (see GCE API). However,
        # images are a global resource and a user can query for images
        # across projects. Therefore we try to remember which project
        # the image belongs to by tracking it in this attribute.
        attribute :project

        READY_STATE = "READY".freeze

        def ready?
          status == READY_STATE
        end

        def destroy(async = true)
          data = service.delete_image(name)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def reload
          requires :name
          data = service.get_image(name, project)
          merge_attributes(data.to_h)
          self
        end

        def save
          requires :name

          data = service.insert_image(name, attributes)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def resource_url
          "#{project}/global/images/#{name}"
        end
      end
    end
  end
end
