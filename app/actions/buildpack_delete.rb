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
          Jobs::GenericEnqueuer.shared.enqueue(blobstore_delete, priority_increment: Jobs::REDUCED_PRIORITY)
        end
      end

      []
    end
  end
end
