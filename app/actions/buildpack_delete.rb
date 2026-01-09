require 'repositories/buildpack_event_repository'

module VCAP::CloudController
  class BuildpackDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(buildpacks)
      buildpacks.each do |buildpack|
        Buildpack.db.transaction do
          Locking[name: 'buildpacks'].lock!
          Repositories::BuildpackEventRepository.new.record_buildpack_delete(buildpack, @user_audit_info)
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
