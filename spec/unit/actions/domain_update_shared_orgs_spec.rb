require 'spec_helper'
require 'actions/domain_update_shared_orgs'
require 'messages/domain_update_shared_orgs_message'

module VCAP::CloudController
  RSpec.describe DomainUpdateSharedOrgs do
    subject { DomainUpdateSharedOrgs }

    describe '#update' do
      context 'when creating a private domain' do
        let(:domain) { create(:private_domain) }
        let(:organization) { create(:organization) }
        let(:shared_org1) { create(:organization) }
        let(:shared_org2) { create(:organization) }

        let(:message) do
          DomainUpdateSharedOrgsMessage.new({
                                              data: [
                                                { guid: shared_org1.guid },
                                                { guid: shared_org2.guid }
                                              ]
                                            })
        end

        it 'updates shared orgs for private domain' do
          subject.update(domain: domain, shared_organizations: [shared_org1, shared_org2])
          domain.reload
          expect(domain.shared_organizations).to contain_exactly(shared_org1, shared_org2)
        end
      end
    end
  end
end
