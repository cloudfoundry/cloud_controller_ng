module VCAP::CloudController
  class PackageDelete
    def delete(packages)
      packages = Array(packages)

      packages.each do |package|
        blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore, nil)
        Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
        package.destroy
      end
    end
  end
end
