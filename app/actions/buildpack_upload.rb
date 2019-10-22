module VCAP::CloudController
  class BuildpackUpload
    def upload_async(message:, buildpack:, config:)
      logger.info("uploading buildpacks bits for buildpack #{buildpack.guid}")

      upload_job = Jobs::V3::BuildpackBits.new(buildpack.guid, message.bits_path, message.bits_name)
      enqueued_job = Jobs::Enqueuer.new(upload_job, queue: Jobs::Queues.local(config)).enqueue_pollable

      enqueued_job
    end

    private

    def config
      VCAP::CloudController::Config.config
    end

    def logger
      @logger ||= Steno.logger('cc.action.buildpack_upload')
    end
  end
end
