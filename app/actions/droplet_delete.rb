require 'repositories/droplet_event_repository'

module VCAP::CloudController
  class DropletDelete
    def initialize(user_audit_info, stagers)
      @user_audit_info = user_audit_info
      @stagers = stagers
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

        fire_and_forget_staging_cancel(droplet)

        droplet.destroy
      end
    end

    private

    def fire_and_forget_staging_cancel(droplet)
      return if droplet.in_final_state?
      @stagers.stager_for_app(droplet.app).stop_stage(droplet.guid)
    rescue => e
      logger.error("failed to request staging cancelation for droplet: #{droplet.guid}, error: #{e.message}")
    end

    def logger
      @logger ||= Steno.logger('cc.droplet_delete')
    end
  end
end
