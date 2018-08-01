module VCAP::CloudController
  class PackageUpload
    class InvalidPackage < StandardError; end

    def upload_async(message:, package:, config:, user_guid:, user_email:, record_event: true)
      logger.info("uploading package bits for package #{package.guid}")

      upload_job = build_job(message, package)
      enqueued_job = nil

      package.db.transaction do
        package.lock!

        package.state = PackageModel::PENDING_STATE
        package.save

        enqueued_job = Jobs::Enqueuer.new(upload_job, queue: Jobs::LocalQueue.new(config)).enqueue

        record_upload(package, user_guid, user_email) if record_event
      end

      enqueued_job
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    def upload_async_without_event(message:, package:, config:)
      upload_async(message: message, package: package, config: config, user_guid: nil, user_email: nil, record_event: false)
    end

    def upload_sync_without_event(message, package)
      logger.info("uploading package bits for package #{package.guid} synchronously")

      upload_job = build_job(message, package)
      upload_job.perform
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def record_upload(package, user_guid, user_email)
      Repositories::PackageEventRepository.record_app_package_upload(
        package,
        user_guid,
        user_email)
    end

    def build_job(message, package)
      Jobs::V3::PackageBits.new(package.guid, message.bits_path, message.cached_resources || [])
    end

    def logger
      @logger ||= Steno.logger('cc.action.package_upload')
    end
  end
end
