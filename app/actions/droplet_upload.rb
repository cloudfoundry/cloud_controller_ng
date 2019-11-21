module VCAP::CloudController
  class DropletUpload
    def upload_async(message:, droplet:, config:, user_audit_info:)
      logger.info("uploading droplet bits for droplet #{droplet.guid}")

      upload_job = build_job(message, droplet)
      enqueued_job = nil

      droplet.db.transaction do
        droplet.lock!

        droplet.state = DropletModel::PROCESSING_UPLOAD_STATE
        droplet.save

        Repositories::DropletEventRepository.record_upload(
          droplet,
          user_audit_info,
          droplet.app.name,
          droplet.space_guid,
          droplet.space.organization_guid
        )

        enqueued_job = Jobs::Enqueuer.new(upload_job, queue: Jobs::Queues.local(config)).enqueue_pollable
      end

      enqueued_job
    end

    private

    def build_job(message, droplet)
      Jobs::V3::DropletUpload.new(message.bits_path, droplet.guid, skip_state_transition: false)
    end

    def logger
      @logger ||= Steno.logger('cc.action.droplet_upload')
    end
  end
end
