module VCAP::CloudController
  class Droplet < Sequel::Model
    many_to_one :app

    def validate
      validates_presence :app
      validates_presence :droplet_hash
    end

    def after_destroy
      super
      droplet_deletion_job = Jobs::Runtime::DropletDeletion.new(new_blobstore_key, old_blobstore_key)
      Jobs::Enqueuer.new(droplet_deletion_job, queue: 'cc-generic').enqueue
    end

    # privatize?
    def file
      if app.staged?
        blob
      end
    end

    def download_to(destination_path)
      key = blobstore_key
      if key
        blobstore.download_from_blobstore(key, destination_path)
      end
    end

    def self.droplet_key(app_guid, digest)
      File.join(app_guid, digest)
    end

    def new_blobstore_key
      self.class.droplet_key(app.guid, droplet_hash)
    end

    def old_blobstore_key
      app.guid
    end

    def blob
      blobstore.blob(new_blobstore_key) || blobstore.blob(old_blobstore_key)
    end

    def update_execution_metadata(metadata)
      update(execution_metadata: metadata)
    end

    def update_detected_start_command(metadata)
      update(detected_start_command: metadata)
    end

    def update_cached_docker_image(image)
      update(cached_docker_image: image)
    end

    private

    def blobstore
      CloudController::DependencyLocator.instance.droplet_blobstore
    end

    def blobstore_key
      if blobstore.exists?(new_blobstore_key)
        return new_blobstore_key
      elsif blobstore.exists?(old_blobstore_key)
        return old_blobstore_key
      end
    end
  end
end
