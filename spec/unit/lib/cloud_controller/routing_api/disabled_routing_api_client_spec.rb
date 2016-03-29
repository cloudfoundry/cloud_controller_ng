require 'spec_helper'

module VCAP::CloudController::RoutingApi
  describe DisabledClient do
    let(:client) { DisabledClient.new }

    describe '.enabled?' do
      it 'returns false' do
        expect(client.enabled?).to be(false)
      end
    end

    describe '.router_groups' do
      it 'raises a routing api disabled error' do
        expect {
          client.router_groups
        }.to raise_error(RoutingApiDisabled)
      end
    end

    describe '.router_group' do
      it 'raises a routing api disabled error' do
        expect {
          client.router_group('guid')
        }.to raise_error(RoutingApiDisabled)
      end
    end
  end
end
