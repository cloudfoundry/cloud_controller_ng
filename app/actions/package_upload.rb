module VCAP::CloudController
  class PackageUpload
    class InvalidPackage < StandardError; end

    def initialize(user_guid, user_email)
      @user_guid  = user_guid
      @user_email = user_email
    end

    def upload_async(message, package, config)
      logger.info("uploading package bits for package #{package.guid}")

      upload_job = build_job(message, package)
      enqueued_job = nil

      package.db.transaction do
        package.lock!

        package.state = PackageModel::PENDING_STATE
        package.save

        enqueued_job = Jobs::Enqueuer.new(upload_job, queue: Jobs::LocalQueue.new(config)).enqueue

        record_upload(package)
      end

      enqueued_job
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    def upload_sync(message, package)
      logger.info("uploading package bits for package #{package.guid} synchronously")

      upload_job = build_job(message, package)
      upload_job.perform

      record_upload(package)
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def record_upload(package)
      Repositories::PackageEventRepository.record_app_package_upload(
        package,
        @user_guid,
        @user_email)
    end

    def build_job(message, package)
      Jobs::V3::PackageBits.new(package.guid, message.bits_path, message.cached_resources || [])
    end

    def logger
      @logger ||= Steno.logger('cc.action.package_upload')
    end
  end
end
