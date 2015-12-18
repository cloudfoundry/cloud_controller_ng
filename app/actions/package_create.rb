require 'repositories/runtime/package_event_repository'

module VCAP::CloudController
  class PackageCreate
    class InvalidPackage < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
    end

    def create(message)
      logger.info("creating package type #{message.type} for app #{message.app_guid}")

      package          = PackageModel.new
      package.app_guid = message.app_guid
      package.type     = message.type
      package.state    = get_package_state(message)

      package.db.transaction do
        package.save
        make_docker_data(message, package)

        Repositories::Runtime::PackageEventRepository.record_app_add_package(
          package,
          @user,
          @user_email,
          message.audit_hash)
      end

      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def get_package_state(message)
      message.bits_type? ? PackageModel::CREATED_STATE : PackageModel::READY_STATE
    end

    def make_docker_data(message, package)
      return nil unless message.docker_type?

      data = PackageDockerDataModel.new
      data.package = package
      data.image = message.docker_data.image
      data.save
      package.docker_data = data
    end

    def logger
      @logger ||= Steno.logger('cc.action.package_create')
    end
  end
end
