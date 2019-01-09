module VCAP::CloudController
  class BuildpackDelete
    def delete(buildpacks)
      buildpacks.each do |buildpack|
        Buildpack.db.transaction do
          if buildpack.key
            blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(buildpack.key, :buildpack_blobstore)
            Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
          end

          buildpack.destroy
        end
      end

      []
    end
  end
end
