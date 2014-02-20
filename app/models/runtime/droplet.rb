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
      Jobs::Enqueuer.new(droplet_deletion_job, queue: "cc-generic").enqueue()
    end

    def download_url
      f = file
      return nil unless f
      return blobstore.download_uri_for_file(f)
    end

    def local_path
      f = file
      f.send(:path) if f
    end

    #privatize?
    def file
      if app.staged? && blobstore_key
        blobstore.file(blobstore_key)
      end
    end

    def download_to(destination_path)
      if blobstore_key
        blobstore.download_from_blobstore(blobstore_key, destination_path)
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
