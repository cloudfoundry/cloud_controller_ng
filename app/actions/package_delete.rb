module VCAP::CloudController
  class PackageDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(packages)
      packages = Array(packages)

      packages.each do |package|
        package_delete = if VCAP::CloudController::Config.config.package_image_registry_configured?
                           Jobs::Kubernetes::RegistryDelete.new(package.bits_image_reference)
                         else
                           Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore)
                         end
        Jobs::Enqueuer.new(package_delete, queue: Jobs::Queues.generic).enqueue
        package.destroy

        Repositories::PackageEventRepository.record_app_package_delete(
          package,
          @user_audit_info)
      end

      []
    end
  end
end
