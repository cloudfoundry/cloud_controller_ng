require 'spec_helper'
require 'presenters/v3/domain_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe DomainPresenter do
    describe '#to_hash' do
      subject do
        DomainPresenter.new(domain).to_hash
      end

      context 'when the domain is public (shared)' do
        let(:domain) do
          VCAP::CloudController::SharedDomain.make(
            name: 'my.domain.com',
            internal: true,
          )
        end

        it 'presents the domain as json' do
          expect(subject[:guid]).to eq(domain.guid)
          expect(subject[:created_at]).to be_a(Time)
          expect(subject[:updated_at]).to be_a(Time)
          expect(subject[:name]).to eq(domain.name)
          expect(subject[:internal]).to eq(domain.internal)
          expect(subject[:relationships][:organization][:data]).to be_nil
          expect(subject[:relationships][:shared_organizations][:data]).to eq([])
          expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}")
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

        it 'presents the base domain properties as json' do
          expect(subject[:guid]).to eq(domain.guid)
          expect(subject[:created_at]).to be_a(Time)
          expect(subject[:updated_at]).to be_a(Time)
          expect(subject[:name]).to eq(domain.name)
          expect(subject[:internal]).to eq(domain.internal)
          expect(subject[:relationships][:organization]).to eq({
            data: { guid: domain.owning_organization.guid }
          })
          expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}")
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

          before do
            shared_org_1.add_private_domain(domain)
            shared_org_2.add_private_domain(domain)
          end

          it 'presents the shared orgs that are visible to a user' do
            expect(subject[:relationships]).to eq({
              organization: { data: { guid: 'org' } },
              shared_organizations: {
                data: [
                  { guid: 'org2' },
                  { guid: 'org3' }
                ]
              }
            })
          end
        end
      end

      context 'when there are decorators' do
        let(:domain) do
          VCAP::CloudController::SharedDomain.make(
            name: 'my.domain.com',
            internal: true,
          )
        end

        let(:banana_decorator) do
          Class.new do
            class << self
              def decorate(hash, domains)
                hash[:included] ||= {}
                hash[:included][:bananas] = domains.map { |domain| "#{domain.name} is bananas" }
                hash
              end
            end
          end
        end

        subject { DomainPresenter.new(domain, decorators: [banana_decorator]).to_hash }

        it 'runs the decorators' do
          expect(subject[:included][:bananas]).to match_array(['my.domain.com is bananas'])
        end
      end
    end
  end
end
