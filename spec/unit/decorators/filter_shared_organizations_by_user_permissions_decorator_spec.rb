require 'spec_helper'

module VCAP::CloudController
  RSpec.describe FilterSharedOrganizationsByUserPermissionsDecorator do
    let(:readable_org_guids_for_user) { ['org-guid-2', 'org-guid-4', 'org-guid-7'] }

    subject do
      FilterSharedOrganizationsByUserPermissionsDecorator.new(readable_org_guids_for_user).decorate(hash, [])
    end

    context 'when given a single domain' do
      let(:hash) do
        {
          relationships: {
            shared_organizations: { data: [{ guid: 'org-guid-1' }, { guid: 'org-guid-2' }, { guid: 'org-guid-3' }, { guid: 'org-guid-4' }] }
          }
        }
      end

      it 'filters the shared orgs from the relationships section' do
        expect(subject[:relationships][:shared_organizations][:data]).to eq([{ guid: 'org-guid-2' }, { guid: 'org-guid-4' }])
      end
    end

    context 'when given a list of domains' do
      let(:hash) do
        {
          resources: [
            {
              relationships: {
                shared_organizations: { data: [{ guid: 'org-guid-1' }, { guid: 'org-guid-2' }, { guid: 'org-guid-3' }, { guid: 'org-guid-7' }] }
              }
            },
            {
              relationships: {
                shared_organizations: { data: [{ guid: 'org-guid-5' }, { guid: 'org-guid-6' }, { guid: 'org-guid-4' }, { guid: 'org-guid-8' }] }
              }
            },
          ]
        }
      end

      it 'filters the shared orgs from the relationships section' do
        expect(subject[:resources][0][:relationships][:shared_organizations][:data]).to eq([{ guid: 'org-guid-2' }, { guid: 'org-guid-7' }])
        expect(subject[:resources][1][:relationships][:shared_organizations][:data]).to eq([{ guid: 'org-guid-4' }])
      end
    end
  end
end
