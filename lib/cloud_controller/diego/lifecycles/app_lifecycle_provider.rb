require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'

module VCAP::CloudController
  class AppLifecycleProvider
    def self.provide(message)
      if message.lifecycle.nil? || message.lifecycle_type == Lifecycles::BUILDPACK
        AppBuildpackLifecycle.new(message)
      elsif message.lifecycle_type == Lifecycles::DOCKER
        AppDockerLifecycle.new
      end
    end
  end
end
