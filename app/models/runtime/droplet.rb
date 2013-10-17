module VCAP::CloudController
  class Droplet < Sequel::Model
    many_to_one :app

    def validate
      validates_presence :app
      validates_presence :droplet_hash
    end

    def before_destroy
      super
      @cached_app_guid_for_delete = app.guid
    end

    def after_destroy_commit
      super
      delete_from_blobstore
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

    def upload(path)
      hash = Digest::SHA1.file(source_path).hexdigest
      blobstore.cp_to_blobstore(
        path,
        File.join(app.guid, hash)
      )
    end

    def delete_from_blobstore
      blobstore.delete(new_blobstore_key)
      begin
        blobstore.delete(old_blobstore_key)
      rescue Errno::EISDIR
        # The new droplets are with a path which is under the old droplet path
        # This means that sometimes, if there are multiple versions of a droplet,
        # the directory will still exist after we delete the droplet.
        # We don't care for now, but we don't want the errors.
      end
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

    def new_blobstore_key
      File.join(@cached_app_guid_for_delete || app.guid, droplet_hash)
    end

    def old_blobstore_key
      @cached_app_guid_for_delete || app.guid
    end
  end
end