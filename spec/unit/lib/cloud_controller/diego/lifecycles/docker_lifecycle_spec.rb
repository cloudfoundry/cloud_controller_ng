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
    let(:staging_message) { DropletCreateMessage.new }

    it_behaves_like 'a lifecycle'

    describe '#pre_known_receipt_information' do
      it 'includes the requested image' do
        expect(lifecycle.pre_known_receipt_information[:docker_receipt_image]).to eq('test-image')
        expect(lifecycle.pre_known_receipt_information[:docker_receipt_username]).to eq('dockerusername')
        expect(lifecycle.pre_known_receipt_information[:docker_receipt_password]).to eq('dockerpassword')
      end
    end
  end
end
