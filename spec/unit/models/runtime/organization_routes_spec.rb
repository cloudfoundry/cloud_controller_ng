require 'spec_helper'

RSpec.describe OrganizationRoutes do
  subject(:organization_routes) { OrganizationRoutes.new(organization) }

  let(:organization) { create(:organization) }

  describe '#count' do
    context 'when there is no spaces' do
      its(:count) { is_expected.to eq 0 }
    end

    context 'when there are spaces' do
      let!(:space) { create(:space, organization:) }

      context 'and there no routes' do
        its(:count) { is_expected.to eq 0 }
      end

      context 'and there are multiple routes' do
        let!(:routes) { 2.times { create(:route, space:) } }

        its(:count) { is_expected.to eq 2 }
      end

      context 'and there are multiple routes' do
        let(:space_2) { create(:space, organization:) }
        let!(:routes) do
          2.times { create(:route, space:) }
          create(:route, space: space_2)
        end

        its(:count) { is_expected.to eq 3 }
      end

      context 'and there is a route belonging to different organization' do
        let!(:route) { create(:route) }

        its(:count) { is_expected.to eq 0 }
      end
    end
  end
end
