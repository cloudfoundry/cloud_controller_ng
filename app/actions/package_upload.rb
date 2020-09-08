module VCAP::CloudController
  class PackageUpload
    class InvalidPackage < StandardError; end

    def upload_async(message:, package:, config:, user_audit_info:, record_event: true)
      logger.info("uploading package bits for package #{package.guid}")

      upload_job = build_job(message, package)
      enqueued_job = nil

      package.db.transaction do
        package.lock!

        package.state = PackageModel::PENDING_STATE
        package.save

        enqueued_job = Jobs::Enqueuer.new(upload_job, queue: Jobs::Queues.local(config)).enqueue

        record_upload(package, user_audit_info) if record_event
      end

      enqueued_job
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    def upload_async_without_event(message:, package:, config:)
      upload_async(message: message, package: package, config: config, user_audit_info: UserAuditInfo.new(user_email: nil, user_guid: nil), record_event: false)
    end

    def upload_sync_without_event(message, package)
      logger.info("uploading package bits for package #{package.guid} synchronously")

      upload_job = build_job(message, package)
      upload_job.perform
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def record_upload(package, user_audit_info)
      Repositories::PackageEventRepository.record_app_package_upload(
        package,
        user_audit_info)
    end

    def build_job(message, package)
      randomized_file_name = randomize_file_name(message.bits_path)
      Jobs::V3::PackageBits.new(package.guid, randomized_file_name, message.resources&.map(&:deep_stringify_keys) || [])
    end

    def randomize_file_name(filepath)
      return filepath if filepath.blank?

      randomized_file_name = "#{filepath}-#{SecureRandom.alphanumeric(10)}"
      File.rename(filepath, randomized_file_name)
      randomized_file_name
    end

    def logger
      @logger ||= Steno.logger('cc.action.package_upload')
    end
  end
end
