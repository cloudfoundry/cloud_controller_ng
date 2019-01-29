module VCAP::CloudController
  class BuildpackDelete
    def delete(buildpacks)
      buildpacks.each do |buildpack|
        Buildpack.db.transaction do
          delete_metadata(buildpack)

          if buildpack.key
            blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(buildpack.key, :buildpack_blobstore)
            Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
          end

          buildpack.destroy
        end
      end

      []
    end

    private

    def delete_metadata(buildpack)
      LabelDelete.delete(buildpack.labels)
      AnnotationDelete.delete(buildpack.annotations)
    end
  end
end
