require 'spec_helper'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'
require_relative 'app_lifecycle_shared'

module VCAP::CloudController
  describe AppDockerLifecycle do
    subject(:lifecycle) { AppDockerLifecycle.new }

    it_behaves_like 'a app lifecycle'
  end
end
