require 'spec_helper'
require 'actions/organization_quotas_create'
require 'messages/organization_quotas_create_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotasCreate do
    describe 'create' do
      subject(:org_quotas_create) { OrganizationQuotasCreate.new }

      context 'when creating a organization quota' do
        let(:message) do
          VCAP::CloudController::OrganizationQuotasCreateMessage.new({
            name: 'my-name',
            total_memory_in_mb: 10,
            paid_services_allowed: false,
            total_service_instances: 1,
            total_routes: 0,
          })
        end

        let(:minimum_message) do
          VCAP::CloudController::OrganizationQuotasCreateMessage.new({
            'name' => 'my-name'
          })
        end

        it 'creates a organization quota with the correct values' do
          organization_quota = org_quotas_create.create(message)
          expect(organization_quota.name).to eq('my-name')
          expect(organization_quota.non_basic_services_allowed).to eq(false)
          expect(organization_quota.memory_limit).to eq(10)
          expect(organization_quota.total_services).to eq(1)
          expect(organization_quota.total_routes).to eq(0)
        end

        it 'provides defaults if the parameters are not provided' do
          organization_quota = org_quotas_create.create(minimum_message)

          expect(organization_quota.name).to eq('my-name')
          expect(organization_quota.non_basic_services_allowed).to eq(true)
          expect(organization_quota.memory_limit).to eq(-1)
          expect(organization_quota.total_services).to eq(-1)
          expect(organization_quota.total_routes).to eq(-1)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::QuotaDefinition).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::OrganizationQuotasCreateMessage.new(name: 'foobar')
          expect {
            org_quotas_create.create(message)
          }.to raise_error(OrganizationQuotasCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          let(:name) { 'Olsen' }
          let(:message) { VCAP::CloudController::OrganizationQuotasCreateMessage.new(name: name) }

          before do
            org_quotas_create.create(message)
          end

          it 'raises a human-friendly error' do
            expect {
              org_quotas_create.create(message)
            }.to raise_error(OrganizationQuotasCreate::Error, "Organization Quota '#{name}' already exists.")
          end
        end
      end
    end
  end
end
