require 'repositories/droplet_event_repository'

module VCAP::CloudController
  class DropletDelete
    def initialize(actor_guid, actor_email)
      @actor_guid = actor_guid
      @actor_name = actor_email
    end

    def delete(droplets)
      droplets = Array(droplets)

      droplets.each do |droplet|
        if droplet.blobstore_key
          blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(droplet.blobstore_key, :droplet_blobstore, nil)
          Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
        end

        Repositories::DropletEventRepository.record_delete(
          droplet,
          @actor_guid,
          @actor_name,
          droplet.app.name,
          droplet.app.space_guid,
          droplet.app.space.organization_guid
        )

        droplet.destroy
      end
    end
  end
end
