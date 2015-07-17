require 'repositories/runtime/package_event_repository'

module VCAP::CloudController
  class PackageCopy
    class InvalidPackage < StandardError; end

    def copy(app_guid, source_package)
      logger.info("copying package #{source_package.guid} to app #{app_guid}")

      package          = PackageModel.new
      package.app_guid = app_guid
      package.type     = source_package.type
      package.url      = source_package.url
      package.state    = source_package.type == 'bits' ? PackageModel::COPYING_STATE : PackageModel::READY_STATE

      package.db.transaction do
        package.save

        if source_package.type == 'bits'
          copy_job = Jobs::V3::PackageBitsCopier.new(source_package.guid, package.guid)
          Jobs::Enqueuer.new(copy_job, queue: 'cc-generic').enqueue
        end
      end

      return package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.package_copy')
    end
  end
end
