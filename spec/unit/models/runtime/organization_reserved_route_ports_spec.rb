require 'spec_helper'

describe OrganizationReservedRoutePorts do
  let(:organization) { VCAP::CloudController::Organization.make }

  subject(:organization_routes) { OrganizationReservedRoutePorts.new(organization) }

  describe '#count' do
    context 'when the org has no spaces' do
      it 'has no reserved ports' do
        expect(subject.count).to eq 0
      end
    end

    context 'when there are spaces' do
      let!(:space) { VCAP::CloudController::Space.make(organization: organization) }
      let!(:space2) { VCAP::CloudController::Space.make(organization: organization) }

      it 'has no reserved ports' do
        expect(subject.count).to eq 0
      end

      context 'and there are multiple ports, reserved or otherwise' do
        before do
          VCAP::CloudController::Route.make(space: space, port: 1234)
          VCAP::CloudController::Route.make(space: space, port: 1234)
          VCAP::CloudController::Route.make(space: space, port: 3455)
          VCAP::CloudController::Route.make(space: space, port: 0)
          VCAP::CloudController::Route.make(space: space2, port: 2222)
          VCAP::CloudController::Route.make(space: space2, port: 2222)
        end

        it 'should have return the number of reserved ports' do
          expect(subject.count).to eq 5
        end
      end
    end
  end
end
