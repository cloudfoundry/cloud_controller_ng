require 'spec_helper'
require_relative 'lifecycle_shared'

module VCAP::CloudController
  describe DockerLifecycle do
    subject(:lifecycle) { DockerLifecycle.new(package, staging_message) }
    let(:package) { PackageModel.make(:docker) }
    let(:staging_message) { DropletCreateMessage.new }

    it_behaves_like 'a lifecycle'

    describe '#pre_known_receipt_information' do
      before do
        package.docker_data.image = 'test-image'
        package.docker_data.save
      end

      it 'includes the requested image' do
        expect(lifecycle.pre_known_receipt_information[:docker_receipt_image]).to eq('test-image')
      end
    end
  end
end
