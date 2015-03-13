require 'spec_helper'
require 'queries/org_delete_fetcher'

module VCAP::CloudController
  describe OrganizationDeleteFetcher do
    describe '#fetch' do
      let(:organization) { Organization.make }
      let(:user) { User.make(admin: admin) }
      let(:admin) { false }

      subject(:organization_delete_fetcher) { OrganizationDeleteFetcher.new(organization.guid) }

      it 'returns the organization' do
        expect(organization_delete_fetcher.fetch).to include(organization)
      end
    end
  end
end
