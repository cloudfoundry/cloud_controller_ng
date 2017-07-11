require 'repositories/droplet_event_repository'

module VCAP::CloudController
  class DropletDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(droplets)
      droplets = Array(droplets)

      droplets.each do |droplet|
        if droplet.blobstore_key
          blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(droplet.blobstore_key, :droplet_blobstore)
          Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
        end

        Repositories::DropletEventRepository.record_delete(
          droplet,
          @user_audit_info,
          droplet.app.name,
          droplet.app.space_guid,
          droplet.app.space.organization_guid
        )

        droplet.destroy
      end

      []
    end

    private

    def logger
      @logger ||= Steno.logger('cc.droplet_delete')
    end
  end
end
