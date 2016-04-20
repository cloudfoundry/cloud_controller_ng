require 'repositories/package_event_repository'

module VCAP::CloudController
  class PackageCopy
    class InvalidPackage < StandardError; end

    def initialize(user_guid, user_email)
      @user_guid = user_guid
      @user_email = user_email
    end

    def copy(app_guid, source_package)
      raise InvalidPackage.new('Source and destination app cannot be the same') if app_guid == source_package.app_guid
      logger.info("copying package #{source_package.guid} to app #{app_guid}")

      package          = PackageModel.new
      package.app_guid = app_guid
      package.type     = source_package.type
      package.state    = source_package.type == 'bits' ? PackageModel::COPYING_STATE : PackageModel::READY_STATE

      package.db.transaction do
        package.save
        copy_docker_data(package, source_package)

        if source_package.type == 'bits'
          copy_job = Jobs::V3::PackageBitsCopier.new(source_package.guid, package.guid)
          Jobs::Enqueuer.new(copy_job, queue: 'cc-generic').enqueue
        end

        Repositories::PackageEventRepository.record_app_package_copy(
          package,
          @user_guid,
          @user_email,
          source_package.guid)
      end

      return package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def copy_docker_data(package, source_package)
      return unless source_package.type == 'docker' && source_package.docker_data
      source_data = source_package.docker_data
      data = PackageDockerDataModel.new
      data.image = source_data.image
      data.package = package
      data.save
      package.reload
    end

    def logger
      @logger ||= Steno.logger('cc.action.package_copy')
    end
  end
end
