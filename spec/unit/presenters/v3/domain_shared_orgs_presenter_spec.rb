require 'spec_helper'
require 'presenters/v3/domain_shared_orgs_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe DomainSharedOrgsPresenter do
    let(:visible_org_guids) { [] }

    describe '#to_hash' do
      let(:domain) do
        VCAP::CloudController::PrivateDomain.make(
          name: 'my.domain.com',
          internal: true,
          owning_organization: org
        )
      end
      subject do
        DomainSharedOrgsPresenter.new(domain, visible_org_guids: visible_org_guids).to_hash
      end

      context 'when the domain is private' do
        let(:org) { VCAP::CloudController::Organization.make(guid: 'org') }

        context 'and has shared organizations' do
          let(:shared_org_1) { VCAP::CloudController::Organization.make(guid: 'org2') }
          let(:shared_org_2) { VCAP::CloudController::Organization.make(guid: 'org3') }
          let(:shared_org_3) { VCAP::CloudController::Organization.make(guid: 'org4') }

          let(:visible_org_guids) { ['org2', 'org3'] }

          before do
            shared_org_1.add_private_domain(domain)
            shared_org_2.add_private_domain(domain)
            shared_org_3.add_private_domain(domain)
          end

          it 'presents the shared orgs that are visible to a user' do
            expect(subject[:data]).to contain_exactly(
              { guid: 'org2' },
                  { guid: 'org3' }
            )
          end
        end

        context 'and has no visible shared organizations' do
          let(:shared_org_1) { VCAP::CloudController::Organization.make(guid: 'org2') }
          let(:shared_org_2) { VCAP::CloudController::Organization.make(guid: 'org3') }
          let(:shared_org_3) { VCAP::CloudController::Organization.make(guid: 'org4') }

          let(:visible_org_guids) { [] }

          before do
            shared_org_1.add_private_domain(domain)
            shared_org_2.add_private_domain(domain)
            shared_org_3.add_private_domain(domain)
          end

          it 'presents an empty shared orgs array' do
            expect(subject).to eq({
              data: []
            })
          end
        end
      end
    end
  end
end
