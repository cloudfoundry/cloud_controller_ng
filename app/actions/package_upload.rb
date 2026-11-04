module VCAP::CloudController
  class PackageUpload
    class InvalidPackage < StandardError; end

    def upload_async(message:, package:, config:, user_audit_info:, record_event: true)
      enqueue(message: message, package: package, config: config, enqueue_as_pollable: true, record_event: record_event) do
        record_upload(package, user_audit_info) if record_event
      end
    end

    def upload_async_without_event(message:, package:, config:)
      enqueue(message: message, package: package, config: config, enqueue_as_pollable: false, record_event: false)
    end

    def upload_sync_without_event(message, package)
      logger.info("uploading package bits for package #{package.guid} synchronously")

      upload_job = build_job(message, package)
      upload_job.perform
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def enqueue(message:, package:, config:, enqueue_as_pollable:, record_event:)
      start_time = Time.now
      log_ctx = { package_guid: package.guid, app_guid: package.app_guid }
      logger.info('package_upload.action.start', log_ctx)

      upload_job = build_job(message, package)
      enqueued_job = nil
      queue = Jobs::Queues.local(config).to_s

      package.db.transaction do
        package.lock!

        package.state = PackageModel::PENDING_STATE
        package.save

        enqueuer = Jobs::Enqueuer.new(queue: queue)
        enqueued_job = enqueue_as_pollable ? enqueuer.enqueue_pollable(upload_job) : enqueuer.enqueue(upload_job)

        yield if block_given?
      end

      logger.info('package_upload.action.enqueued', log_ctx.merge(
                                                      queue: queue,
                                                      job_guid: enqueued_job&.guid,
                                                      delayed_job_guid: delayed_job_guid(enqueued_job),
                                                      record_event: record_event,
                                                      duration_ms: elapsed_ms(start_time)
                                                    ))
      enqueued_job
    rescue Sequel::ValidationFailed => e
      logger.info('package_upload.action.failed', log_ctx.merge(error: e.message))
      raise InvalidPackage.new(e.message)
    end

    def delayed_job_guid(job)
      return job.delayed_job_guid if job.respond_to?(:delayed_job_guid)

      job&.guid
    end

    def record_upload(package, user_audit_info)
      Repositories::PackageEventRepository.record_app_package_upload(
        package,
        user_audit_info
      )
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

    def elapsed_ms(start_time)
      ((Time.now - start_time) * 1000).round
    end
  end
end
