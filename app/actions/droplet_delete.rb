require 'repositories/droplet_event_repository'

module VCAP::CloudController
  class DropletDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(droplets)
      droplets = Array(droplets)

      droplets.each do |droplet|
        DropletModel.db.transaction do
          droplet.destroy
        end

        if droplet.blobstore_key
          blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(droplet.blobstore_key, :droplet_blobstore)
          Jobs::GenericEnqueuer.shared.enqueue(blobstore_delete, priority_increment: Jobs::REDUCED_PRIORITY)
        end

        Repositories::DropletEventRepository.record_delete(
          droplet,
          @user_audit_info,
          droplet.app.name,
          droplet.app.space_guid,
          droplet.app.space.organization_guid
        )
      end

      []
    end

    private

    def logger
      @logger ||= Steno.logger('cc.droplet_delete')
    end
  end
end
