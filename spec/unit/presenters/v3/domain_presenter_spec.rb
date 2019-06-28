require 'spec_helper'
require 'presenters/v3/domain_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe DomainPresenter do
    let(:visible_org_guids) { [] }

    describe '#to_hash' do
      subject do
        DomainPresenter.new(domain, visible_org_guids: visible_org_guids).to_hash
      end

      context 'when the domain is public (shared)' do
        let(:domain) do
          VCAP::CloudController::SharedDomain.make(
            name: 'my.domain.com',
            internal: true
          )
        end

        let!(:domain_label) do
          VCAP::CloudController::DomainLabelModel.make(
            resource_guid: domain.guid,
            key_prefix: 'maine.gov',
            key_name: 'potato',
            value: 'mashed'
          )
        end

        let!(:domain_annotation) do
          VCAP::CloudController::DomainAnnotationModel.make(
            resource_guid: domain.guid,
            key: 'contacts',
            value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
          )
        end

        it 'presents the domain as json' do
          expect(subject[:guid]).to eq(domain.guid)
          expect(subject[:created_at]).to be_a(Time)
          expect(subject[:updated_at]).to be_a(Time)
          expect(subject[:name]).to eq(domain.name)
          expect(subject[:internal]).to eq(domain.internal)
          expect(subject[:metadata][:labels]).to eq({ 'maine.gov/potato' => 'mashed' })
          expect(subject[:metadata][:annotations]).to eq({ 'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)' })
          expect(subject[:relationships][:organization][:data]).to be_nil
          expect(subject[:relationships][:shared_organizations][:data]).to eq([])
          expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}")
          expect(subject[:links][:organization]).to be_nil
          expect(subject[:links][:route_reservations][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}/route_reservations")
          expect(subject[:links][:shared_organizations]).to be_nil
        end
      end

      context 'when the domain is private' do
        let(:org) { VCAP::CloudController::Organization.make(guid: 'org') }
        let(:domain) do
          VCAP::CloudController::PrivateDomain.make(
            name: 'my.domain.com',
            internal: true,
            owning_organization: org
          )
        end

        let!(:domain_label) do
          VCAP::CloudController::DomainLabelModel.make(
            resource_guid: domain.guid,
            key_prefix: 'maine.gov',
            key_name: 'potato',
            value: 'mashed'
          )
        end

        let!(:domain_annotation) do
          VCAP::CloudController::DomainAnnotationModel.make(
            resource_guid: domain.guid,
            key: 'contacts',
            value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
          )
        end

        it 'presents the base domain properties as json' do
          expect(subject[:guid]).to eq(domain.guid)
          expect(subject[:created_at]).to be_a(Time)
          expect(subject[:updated_at]).to be_a(Time)
          expect(subject[:name]).to eq(domain.name)
          expect(subject[:internal]).to eq(domain.internal)
          expect(subject[:metadata][:labels]).to eq({ 'maine.gov/potato' => 'mashed' })
          expect(subject[:metadata][:annotations]).to eq({ 'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)' })
          expect(subject[:relationships][:organization]).to eq({
            data: { guid: domain.owning_organization.guid }
          })
          expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}")
          expect(subject[:links][:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{domain.owning_organization.guid}")
          expect(subject[:links][:route_reservations][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}/route_reservations")
          expect(subject[:links][:shared_organizations][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}/relationships/shared_organizations")
        end

        context 'and has no shared organizations' do
          it 'presents shared orgs as an empty array' do
            expect(subject[:relationships]).to eq({
              organization: { data: { guid: domain.owning_organization.guid } },
              shared_organizations: { data: [] }
            })
          end
        end

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
            expect(subject[:relationships]).to match({
              organization: { data: { guid: 'org' } },
              shared_organizations: {
                data: contain_exactly(
                  { guid: 'org2' },
                  { guid: 'org3' }
                ),
              }
            })
          end
        end
      end
    end
  end
end
