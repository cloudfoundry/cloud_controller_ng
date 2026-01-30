module VCAP::CloudController
  class BuildpackUpload
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def upload_async(message:, buildpack:, config:)
      logger.info("uploading buildpacks bits for buildpack #{buildpack.guid}")

      upload_job = Jobs::V3::BuildpackBits.new(buildpack.guid, message.bits_path, message.bits_name, @user_audit_info, message.audit_hash)
      Jobs::Enqueuer.new(queue: Jobs::Queues.local(config)).enqueue_pollable(upload_job)
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
