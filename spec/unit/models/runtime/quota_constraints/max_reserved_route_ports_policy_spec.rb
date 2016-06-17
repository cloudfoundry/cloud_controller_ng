require 'spec_helper'

module VCAP::CloudController
  RSpec.describe MaxReservedRoutePortsPolicy do
    let(:quota_definition) do
      instance_double(VCAP::CloudController::QuotaDefinition,
                      total_reserved_route_ports: 4,
                      total_routes: 4)
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

      context 'when total allowed reserved route ports is unlimited and total routes is finite' do
        let(:quota_definition) do
          instance_double(VCAP::CloudController::QuotaDefinition,
                          total_reserved_route_ports: -1,
                          total_routes: 4)
        end

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
      end

      context 'when an unlimited amount of routes are available' do
        let(:quota_definition) do
          instance_double(VCAP::CloudController::QuotaDefinition,
                          total_reserved_route_ports: -1,
                          total_routes: -1)
        end

        it 'is always true' do
          result = subject.allow_more_route_ports?
          expect(result).to be_truthy
        end
      end
    end
  end
end
