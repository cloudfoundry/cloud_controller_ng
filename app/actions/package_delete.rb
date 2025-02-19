module VCAP::CloudController
  class PackageDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(packages)
      packages = Array(packages)

      packages.each do |package|
        unless package.docker?
          package_src_delete_job = create_package_source_deletion_job(package)
          Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue(package_src_delete_job) if package_src_delete_job
        end

        package.destroy

        Repositories::PackageEventRepository.record_app_package_delete(
          package,
          @user_audit_info
        )
      end

      []
    end

    private

    def create_package_source_deletion_job(package)
      Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore)
    end
  end
end
