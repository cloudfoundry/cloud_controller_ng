require 'spec_helper'
require 'actions/domain_create'
require 'messages/domain_create_message'

module VCAP::CloudController
  RSpec.describe DomainCreate do
    subject { DomainCreate.new }

    let(:name) { 'example.com' }

    describe '#create' do
      context 'when there is a sequel validation error' do
        context 'when the validation error is non-specific' do
          let(:private_domain) { PrivateDomain.make }
          let(:domain) { "sub.#{private_domain.name}" }
          let(:message) { DomainCreateMessage.new({ name: domain }) }

          it 'returns an error' do
            expect {
              subject.create(message: message)
            }.to raise_error(DomainCreate::Error, %{The domain name "#{domain}" cannot be created because "#{private_domain.name}" is already reserved by another domain})
          end
        end

        context 'when the error is a uniqueness error' do
          let(:existing_domain) { SharedDomain.make }
          let(:message) { DomainCreateMessage.new({ name: existing_domain.name }) }

          it 'returns an informative error message' do
            expect {
              subject.create(message: message)
            }.to raise_error(DomainCreate::Error, %{The domain name "#{existing_domain.name}" is already in use})
          end
        end

        context 'when the error is a quota error' do
          let(:org) { Organization.make(quota_definition: VCAP::CloudController::QuotaDefinition.make(total_private_domains: 0)) }
          let(:message) { DomainCreateMessage.new({ name: 'foo.com', relationships: { organization: { data: { guid: org.guid } } } }) }

          it 'returns an informative error message' do
            expect {
              subject.create(message: message)
            }.to raise_error(DomainCreate::Error, "The number of private domains exceeds the quota for organization \"#{org.name}\"")
          end
        end
      end

      context 'when creating a shared domain' do
        context 'provided every valid field' do
          let(:internal) { true }

          let(:message) do
            DomainCreateMessage.new({
              name: name,
              internal: internal,
            })
          end

          it 'creates a domain with all the provided fields' do
            domain = nil

            expect {
              domain = subject.create(message: message)
            }.to change { SharedDomain.count }.by(1)

            expect(domain.name).to eq(name)
            expect(domain.internal).to eq(internal)
            expect(domain.guid).to_not be_nil
          end
        end
      end

      context 'when creating a private domain' do
        let(:organization) { Organization.make }
        let(:shared_org1) { Organization.make }
        let(:shared_org2) { Organization.make }

        let(:message) do
          DomainCreateMessage.new({
            name: name,
            relationships: {
              organization: {
                data: { guid: organization.guid }
              },
              shared_organizations: {
                data: [
                  { guid: shared_org1.guid },
                  { guid: shared_org2.guid }
                ]
              }
            },
          })
        end

        it 'creates a private domain' do
          expect {
            subject.create(message: message, shared_organizations: [shared_org1, shared_org2])
          }.to change { PrivateDomain.count }.by(1)

          domain = PrivateDomain.last
          expect(domain.name).to eq name
          expect(domain.owning_organization_guid).to eq organization.guid
          expect(domain.shared_organizations).to contain_exactly(shared_org1, shared_org2)
        end
      end
    end
  end
end
