require 'repositories/package_event_repository'

module VCAP::CloudController
  class PackageCopy
    class InvalidPackage < StandardError; end

    attr_reader :enqueued_job

    def copy(destination_app_guid:, source_package:, user_audit_info:, record_event: true)
      raise InvalidPackage.new('Source and destination app cannot be the same') if destination_app_guid == source_package.app_guid
      logger.info("copying package #{source_package.guid} to app #{destination_app_guid}")

      package              = PackageModel.new
      package.app_guid     = destination_app_guid
      package.type         = source_package.type
      package.state        = source_package.bits? ? PackageModel::COPYING_STATE : PackageModel::READY_STATE
      package.docker_image = source_package.docker_image

      package.db.transaction do
        package.save

        if source_package.type == 'bits'
          @enqueued_job = Jobs::Enqueuer.new(
            Jobs::V3::PackageBitsCopier.new(source_package.guid, package.guid),
            queue: 'cc-generic'
          ).enqueue
        end

        record_audit_event(package, source_package, user_audit_info) if record_event
      end

      return package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    def copy_without_event(destination_app_guid, source_package)
      copy(destination_app_guid: destination_app_guid, source_package: source_package, user_audit_info: UserAuditInfo.new(user_email: nil, user_guid: nil), record_event: false)
    end

    private

    def record_audit_event(package, source_package, user_audit_info)
      Repositories::PackageEventRepository.record_app_package_copy(
        package,
        user_audit_info,
        source_package.guid)
    end

    def logger
      @logger ||= Steno.logger('cc.action.package_copy')
    end
  end
end
