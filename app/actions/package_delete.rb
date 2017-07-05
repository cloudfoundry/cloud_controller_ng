module VCAP::CloudController
  class PackageDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(packages)
      packages = Array(packages)

      packages.each do |package|
        blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore)
        Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
        package.destroy

        Repositories::PackageEventRepository.record_app_package_delete(
          package,
          @user_audit_info)
      end

      []
    end
  end
end
