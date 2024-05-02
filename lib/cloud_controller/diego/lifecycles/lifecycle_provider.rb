require 'cloud_controller/diego/lifecycles/buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/docker_lifecycle'
require 'cloud_controller/diego/lifecycles/cnb_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class LifecycleProvider
    TYPE_TO_LIFECYCLE_CLASS_MAP = {
      VCAP::CloudController::Lifecycles::BUILDPACK => BuildpackLifecycle,
      VCAP::CloudController::Lifecycles::DOCKER => DockerLifecycle,
      VCAP::CloudController::Lifecycles::CNB => CNBLifecycle
    }.freeze

    def self.provide(package, message)
      type = if message.requested?(:lifecycle)
               message.lifecycle_type
             else
               package.app.lifecycle_type
             end

      TYPE_TO_LIFECYCLE_CLASS_MAP[type].new(package, message)
    end
  end
end
