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
      package.url      = message.url
      package.state    = message.type == 'bits' ? PackageModel::CREATED_STATE : PackageModel::READY_STATE

      package.db.transaction do
        package.save

        Repositories::Runtime::PackageEventRepository.record_app_add_package(
          package,
          @user,
          @user_email,
          message.as_json({ only: message.requested_keys.map(&:to_s) })
        )
      end

      package
    rescue Sequel::ValidationFailed => e
      raise InvalidPackage.new(e.message)
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.package_create')
    end
  end
end
