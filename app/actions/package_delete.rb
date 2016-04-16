module VCAP::CloudController
  class PackageDelete
    def initialize(user, user_email)
      @user = user
      @user_email = user_email
    end

    def delete(packages)
      packages = Array(packages)

      packages.each do |package|
        blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore, nil)
        Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
        package.destroy

        Repositories::Runtime::PackageEventRepository.record_app_package_delete(
          package,
          @user,
          @user_email)
      end
    end
  end
end
