require 'spec_helper'

RSpec.describe DockerPolicy do
  subject(:validator) { DockerPolicy.new(process) }

  let(:process) { VCAP::CloudController::ProcessModelFactory.make(:docker, docker_image: 'some-image:latest') }

  context 'when a buildpack is specified' do
    before do
      allow(process).to receive(:buildpack_specified?).and_return(true)
    end

    it 'registers an appropriate error' do
      expect(validator).to validate_with_error(process, :docker_image, DockerPolicy::BUILDPACK_DETECTED_ERROR_MSG)
    end
  end

  context 'when Docker is disabled' do
    before do
      VCAP::CloudController::FeatureFlag.create(name: 'diego_docker', enabled: false)
    end

    context 'when process is being started' do
      before do
        allow(process).to receive(:being_started?).and_return(true)
      end

      it 'registers an appropriate error' do
        expect(validator).to validate_with_error(process, :docker, :docker_disabled)
      end
    end

    context 'when process is being stopped' do
      before do
        allow(process).to receive(:being_started?).and_return(false)
      end

      it 'does not register an error' do
        expect(validator).to validate_without_error(process)
      end
    end
  end

  context 'when Docker is enabled' do
    before do
      VCAP::CloudController::FeatureFlag.create(name: 'diego_docker', enabled: true)
    end

    it 'does not register an error' do
      expect(validator).to validate_without_error(process)
    end
  end
end
