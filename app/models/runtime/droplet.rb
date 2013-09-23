module CloudController
  class Droplet
    def initialize(app, droplet_blobstore)
      @app = app
      @blobstore = droplet_blobstore
    end

    def delete
      blobstore.delete(blobstore_key)
      blobstore.delete(old_blobstore_key)
    end

    def exists?
      return false unless app.droplet_hash

      blobstore.exists?(blobstore_key) ||
        blobstore.exists?(old_blobstore_key)
    end

    def save(source_path)
      blobstore.cp_to_blobstore(
        source_path,
        blobstore_key
      )
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