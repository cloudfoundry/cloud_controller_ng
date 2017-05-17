require 'spec_helper'
require_relative 'lifecycle_shared'

module VCAP::CloudController
  RSpec.describe DockerLifecycle do
    subject(:lifecycle) { DockerLifecycle.new(package, staging_message) }
    let(:package) do
      PackageModel.make(:docker,
                        docker_image: 'test-image',
                        docker_username: 'dockerusername',
                        docker_password: 'dockerpassword',
                       )
    end
    let(:staging_message) { BuildCreateMessage.new }

    it_behaves_like 'a lifecycle'
  end
end
