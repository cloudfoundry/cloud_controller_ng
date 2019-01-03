module VCAP::CloudController
  class BuildpackUpload
    class InvalidBuildpack < StandardError
    end

    def upload_async(message:, buildpack:, config:)
      logger.info("uploading buildpacks bits for buildpack #{buildpack.guid}")

      upload_job = Jobs::V3::BuildpackBits.new(buildpack.guid, message.bits_path, message.bits_name)
      enqueued_job = Jobs::Enqueuer.new(upload_job, queue: Jobs::LocalQueue.new(config)).enqueue

      enqueued_job
    rescue Sequel::ValidationFailed => e
      raise InvalidBuildpack.new(e.message)
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
