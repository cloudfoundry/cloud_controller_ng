module VCAP::CloudController
  class BuildpackDelete
    def delete(buildpacks)
      buildpacks.each do |buildpack|
        Buildpack.db.transaction do
          Locking[name: 'buildpacks'].lock!

          if buildpack.key
            blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(buildpack.key, :buildpack_blobstore)
            Jobs::Enqueuer.new(blobstore_delete, queue: Jobs::Queues.generic).enqueue
          end

          buildpack.destroy
        end
      end

      []
    end
  end
end
