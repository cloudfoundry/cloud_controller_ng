require 'spec_helper'

describe MaxReservedRoutePortsPolicy do
  let(:quota_definition) do
    instance_double(VCAP::CloudController::QuotaDefinition,
                    total_reserved_route_ports: 4)
  end
  let(:port_counter) { instance_double(OrganizationReservedRoutePorts, count: 0) }

  subject { MaxReservedRoutePortsPolicy.new(quota_definition, port_counter) }

  describe '#allow_more_route_ports?' do
    context 'when equal to the total allowed reserved route ports' do
      let(:port_counter) { instance_double(OrganizationReservedRoutePorts, count: 4) }

      it 'is false' do
        result = subject.allow_more_route_ports?
        expect(result).to be_falsy
      end
    end

    context 'when less than the total allowed reserved route ports' do
      let(:port_counter) { instance_double(OrganizationReservedRoutePorts, count: 3) }

      it 'is true' do
        result = subject.allow_more_route_ports?
        expect(result).to be_truthy
      end
    end

    context 'when greater than the total allowed reserved route ports' do
      let(:port_counter) { instance_double(OrganizationReservedRoutePorts, count: 5) }

      it 'is false' do
        result = subject.allow_more_route_ports?
        expect(result).to be_falsy
      end
    end

    context 'when an unlimited amount of routes are available' do
      let(:quota_definition) { instance_double(VCAP::CloudController::QuotaDefinition, total_reserved_route_ports: -1) }

      it 'is always true' do
        result = subject.allow_more_route_ports?
        expect(result).to be_truthy
      end
    end
  end
end
