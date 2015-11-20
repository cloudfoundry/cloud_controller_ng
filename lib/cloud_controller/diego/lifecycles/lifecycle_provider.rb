require 'cloud_controller/diego/lifecycles/buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/docker_lifecycle'

module VCAP::CloudController
  class LifecycleProvider
    def self.provide(package, staging_message)
      if staging_message.lifecycle_type == 'buildpack'
        BuildpackLifecycle.new(package, staging_message)
      elsif staging_message.lifecycle_type == 'docker'
        DockerLifecycle.new(package, staging_message)
      end
    end
  end
end
