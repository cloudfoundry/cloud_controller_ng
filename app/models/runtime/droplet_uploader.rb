module CloudController
  class DropletUploader
    def initialize(app, blobstore)
      @app = app
      @blobstore = blobstore
    end

    def upload(source_path, droplets_to_keep=2)
      digest = Digester.new.digest_path(source_path)
      blobstore.cp_to_blobstore(
        source_path,
        VCAP::CloudController::Droplet.droplet_key(app.guid, digest)
      )
      app.add_new_droplet(digest)
      current_droplet_size = app.droplets_dataset.count

      if current_droplet_size > droplets_to_keep
        app.droplets_dataset.
          order_by(Sequel.asc(:created_at)).
          limit(current_droplet_size - droplets_to_keep).destroy
      end

      app.save
    end

    private

    attr_reader :blobstore, :app
  end
end
