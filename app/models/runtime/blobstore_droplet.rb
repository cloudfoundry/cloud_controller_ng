module CloudController
  class BlobstoreDroplet
    def initialize(app, blobstore)
      @app = app
      @blobstore = blobstore
    end

    def file
      return unless @app.staged?
      blobstore.file(blobstore_key) || blobstore.file(old_blobstore_key)
    end

    def local_path
      f = file
      f.send(:path) if f
    end

    def download_url
      f = file
      return nil unless f
      return blobstore.download_uri_for_file(f)
    end

    def delete
      blobstore.delete(blobstore_key)
      begin
        blobstore.delete(old_blobstore_key)
      rescue Errno::EISDIR
        # The new droplets are with a path which is under the old droplet path
        # This means that sometimes, if there are multiple versions of a droplet,
        # the directory will still exist after we delete the droplet.
        # We don't care for now, but we don't want the errors.
      end
    end

    def exists?
      return false unless app.droplet_hash

      blobstore.exists?(blobstore_key) ||
        blobstore.exists?(old_blobstore_key)
    end

    def save(source_path)
      hash = Digest::SHA1.file(source_path).hexdigest
      blobstore.cp_to_blobstore(
        source_path,
        File.join(app.guid, hash)
      )
      app.droplet_hash = hash
    end

    private
    attr_reader :blobstore, :app

    def blobstore_key
      File.join(app.guid, app.droplet_hash)
    end

    def old_blobstore_key
      app.guid
    end
  end
end
