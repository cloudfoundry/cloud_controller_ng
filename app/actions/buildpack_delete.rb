module VCAP::CloudController
  class BuildpackDelete
    def delete(buildpacks)
      buildpacks.each do |buildpack|
        Buildpack.db.transaction do
          Locking[name: 'buildpacks'].lock!
          buildpack.destroy
        end
        if buildpack.key
          blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(buildpack.key, :buildpack_blobstore)
          Jobs::Enqueuer.new(blobstore_delete, queue: Jobs::Queues.generic).enqueue
        end
      end

      []
    end
  end
end
