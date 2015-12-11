require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class AppLifecycleProvider
    TYPE_TO_LIFECYCLE_CLASS_MAP = {
      VCAP::CloudController::Lifecycles::BUILDPACK => AppBuildpackLifecycle,
      VCAP::CloudController::Lifecycles::DOCKER    => AppDockerLifecycle
    }
    DEFAULT_LIFECYCLE_TYPE = VCAP::CloudController::Lifecycles::BUILDPACK

    def self.provide(message, app=nil)
      if message.requested?(:lifecycle)
        type = message.lifecycle_type
      elsif app
        type = app.lifecycle_type
      else
        type = DEFAULT_LIFECYCLE_TYPE
      end

      TYPE_TO_LIFECYCLE_CLASS_MAP[type].new(message)
    end
  end
end
