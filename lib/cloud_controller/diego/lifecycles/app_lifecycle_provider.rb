require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'
require 'cloud_controller/diego/lifecycles/app_cnb_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class AppLifecycleProvider
    TYPE_TO_LIFECYCLE_CLASS_MAP = {
      VCAP::CloudController::Lifecycles::BUILDPACK => AppBuildpackLifecycle,
      VCAP::CloudController::Lifecycles::DOCKER => AppDockerLifecycle,
      VCAP::CloudController::Lifecycles::CNB => AppCNBLifecycle
    }.freeze

    def self.provide_for_create(message)
      provide(message, nil)
    end

    def self.provide_for_update(message, app)
      provide(message, app)
    end

    def self.provide(message, app)
      type = if message.lifecycle_type.present?
               message.lifecycle_type
             elsif !app.nil?
               app.lifecycle_type
             else
               Config.config.get(:default_app_lifecycle)
             end

      TYPE_TO_LIFECYCLE_CLASS_MAP[type].new(message)
    end
    private_class_method :provide
  end
end
