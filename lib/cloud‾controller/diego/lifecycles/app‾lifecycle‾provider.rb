require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class AppLifecycleProvider
    TYPE_TO_LIFECYCLE_CLASS_MAP = {
      VCAP::CloudController::Lifecycles::BUILDPACK => AppBuildpackLifecycle,
      VCAP::CloudController::Lifecycles::DOCKER    => AppDockerLifecycle
    }.freeze
    DEFAULT_LIFECYCLE_TYPE = VCAP::CloudController::Lifecycles::BUILDPACK

    def self.provide_for_create(message)
      provide(message, nil)
    end

    def self.provide_for_update(message, app)
      provide(message, app)
    end

    def self.provide(message, app)
      type = if message.requested?(:lifecycle)
               message.lifecycle_type
             elsif !app.nil?
               app.lifecycle_type
             else
               DEFAULT_LIFECYCLE_TYPE
             end

      TYPE_TO_LIFECYCLE_CLASS_MAP[type].new(message)
    end
    private_class_method :provide
  end
end
