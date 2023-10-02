require 'spec_helper'

RSpec.describe OrganizationRoutes do
  subject(:organization_routes) { OrganizationRoutes.new(organization) }

  let(:organization) { VCAP::CloudController::Organization.make }

  describe '#count' do
    context 'when there is no spaces' do
      its(:count) { is_expected.to eq 0 }
    end

    context 'when there are spaces' do
      let!(:space) { VCAP::CloudController::Space.make(organization:) }

      context 'and there no routes' do
        its(:count) { is_expected.to eq 0 }
      end

      context 'and there are multiple routes' do
        let!(:routes) { 2.times { VCAP::CloudController::Route.make(space:) } }

        its(:count) { is_expected.to eq 2 }
      end

      context 'and there are multiple routes' do
        let(:space_2) { VCAP::CloudController::Space.make(organization:) }
        let!(:routes) do
          2.times { VCAP::CloudController::Route.make(space:) }
          VCAP::CloudController::Route.make(space: space_2)
        end

        its(:count) { is_expected.to eq 3 }
      end

      context 'and there is a route belonging to different organization' do
        let!(:route) { VCAP::CloudController::Route.make }

        its(:count) { is_expected.to eq 0 }
      end
    end
  end
end
