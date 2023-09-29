require 'spec_helper'

module VCAP::CloudController::RoutingApi
  RSpec.describe DisabledClient do
    let(:client) { DisabledClient.new }

    describe '.enabled?' do
      it 'returns false' do
        expect(client.enabled?).to be(false)
      end
    end

    describe '.router_groups' do
      it 'raises a routing api disabled error' do
        expect do
          client.router_groups
        end.to raise_error(RoutingApiDisabled)
      end
    end

    describe '.router_group' do
      it 'raises a routing api disabled error' do
        expect do
          client.router_group('guid')
        end.to raise_error(RoutingApiDisabled)
      end
    end

    describe '.router_group_guid' do
      it 'raises a routing api disabled error' do
        expect do
          client.router_group_guid('group name')
        end.to raise_error(RoutingApiDisabled)
      end
    end
  end
end
