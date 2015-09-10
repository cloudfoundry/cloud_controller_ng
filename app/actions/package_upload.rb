module VCAP::CloudController
  class PackageUpload
    class InvalidPackage < StandardError; end

    def upload(message, package, config)
      logger.info("uploading package bits for package #{package.guid}")

      bits_upload_job = Jobs::V3::PackageBits.new(package.guid, message.bits_path)

      package.db.transaction do
        package.lock!

        package.state = PackageModel::PENDING_STATE
        package.save

        Jobs::Enqueuer.new(bits_upload_job, queue: Jobs::LocalQueue.new(config)).enqueue
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.package_upload')
    end
  end
end
