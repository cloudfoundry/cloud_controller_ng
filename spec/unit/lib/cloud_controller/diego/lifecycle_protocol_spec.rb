require 'spec_helper'
require 'cloud_controller/diego/lifecycle_protocol'

module VCAP::CloudController::Diego
  RSpec.describe LifecycleProtocol do
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
    end
  end
end
