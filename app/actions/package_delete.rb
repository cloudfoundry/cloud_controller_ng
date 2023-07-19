module VCAP::CloudController
  class PackageDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(packages)
      packages = Array(packages)

      packages.each do |package|
        package_src_delete_job = create_package_source_deletion_job(package)
        Jobs::Enqueuer.new(package_src_delete_job, queue: Jobs::Queues.generic).enqueue if package_src_delete_job
        package.destroy

        Repositories::PackageEventRepository.record_app_package_delete(
          package,
          @user_audit_info)
      end

      []
    end

    private

    def create_package_source_deletion_job(package)
      return Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore) unless package_registry_configured?

      nil
    end

    def package_registry_configured?
      VCAP::CloudController::Config.config.package_image_registry_configured?
    end
  end
end
