require 'lightweight_spec_helper'
require 'cloud_controller/diego/lifecycles/lifecycles'
require 'cloud_controller/diego/lifecycle_protocol'
require 'cloud_controller/diego/buildpack/lifecycle_protocol'
require 'cloud_controller/diego/cnb/lifecycle_protocol'
require 'cloud_controller/diego/docker/lifecycle_protocol'

module CloudController
  class DependencyLocator
  end
end unless defined?(::CloudController::DependencyLocator)

module VCAP::CloudController::Diego
  RSpec.describe LifecycleProtocol do
    before do
      dependency_locator = double(:dependency_locator,
                                  blobstore_url_generator: double(:blobstore_url_generator),
                                  droplet_url_generator: double(:droplet_url_generator))
      allow(::CloudController::DependencyLocator).to receive(:instance).and_return(dependency_locator)
    end

    describe '.protocol_for_type' do
      subject(:protocol) { LifecycleProtocol.protocol_for_type(type) }

      context 'with BUILDPACK' do
        let(:type) { VCAP::CloudController::Lifecycles::BUILDPACK }

        it 'returns a buildpack lifecycle protocol' do
          expect(protocol).to be_a(VCAP::CloudController::Diego::Buildpack::LifecycleProtocol)
        end
      end

      context 'with DOCKER' do
        let(:type) { VCAP::CloudController::Lifecycles::DOCKER }

        it 'returns a buildpack lifecycle protocol' do
          expect(protocol).to be_a(VCAP::CloudController::Diego::Docker::LifecycleProtocol)
        end
      end

      context 'with CNB' do
        let(:type) { VCAP::CloudController::Lifecycles::CNB }

        it 'returns a cnb lifecycle protocol' do
          expect(protocol).to be_a(VCAP::CloudController::Diego::CNB::LifecycleProtocol)
        end
      end
    end
  end
end
