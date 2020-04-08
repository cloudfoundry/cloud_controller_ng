require 'spec_helper'
require 'actions/organization_quotas_create'
require 'messages/organization_quotas_create_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotasCreate do
    describe 'create' do
      subject(:org_quotas_create) { OrganizationQuotasCreate.new }

      context 'when creating a organization quota' do
        let(:org) { VCAP::CloudController::Organization.make }

        let(:message) do
          VCAP::CloudController::OrganizationQuotasCreateMessage.new({
            name: 'my-name',
            apps: {
              total_memory_in_mb: 1,
              per_process_memory_in_mb: 2,
              total_instances: 3,
              per_app_tasks: 4
            },
            services: {
              paid_services_allowed: false,
              total_service_instances: 5,
              total_service_keys: 6
            },
            routes: {
              total_reserved_ports: 7,
              total_routes: 8
            },
            domains: {
              total_domains: 9
            }
          })
        end

        let(:minimum_message) do
          VCAP::CloudController::OrganizationQuotasCreateMessage.new({
            'name' => 'my-name',
            'relationships' => { organizations: { data: [] } },
          })
        end

        let(:message_with_org) do
          VCAP::CloudController::OrganizationQuotasCreateMessage.new({
            'name' => 'my-name',
            'relationships' => { organizations: { data: [{ guid: org.guid }] } },
          })
        end

        it 'creates a organization quota with the correct values' do
          organization_quota = org_quotas_create.create(message)

          expect(organization_quota.name).to eq('my-name')

          expect(organization_quota.memory_limit).to eq(1)
          expect(organization_quota.instance_memory_limit).to eq(2)
          expect(organization_quota.app_instance_limit).to eq(3)
          expect(organization_quota.app_task_limit).to eq(4)

          expect(organization_quota.total_services).to eq(5)
          expect(organization_quota.total_service_keys).to eq(6)
          expect(organization_quota.non_basic_services_allowed).to eq(false)

          expect(organization_quota.total_reserved_route_ports).to eq(7)
          expect(organization_quota.total_routes).to eq(8)

          expect(organization_quota.total_private_domains).to eq(9)

          expect(organization_quota.organizations.count).to eq(0)
        end

        it 'provides defaults if the parameters are not provided' do
          organization_quota = org_quotas_create.create(minimum_message)

          expect(organization_quota.name).to eq('my-name')

          expect(organization_quota.memory_limit).to eq(-1)
          expect(organization_quota.instance_memory_limit).to eq(-1)
          expect(organization_quota.app_instance_limit).to eq(-1)
          expect(organization_quota.app_task_limit).to eq(-1)

          expect(organization_quota.total_services).to eq(-1)
          expect(organization_quota.total_service_keys).to eq(-1)
          expect(organization_quota.non_basic_services_allowed).to eq(true)

          expect(organization_quota.total_routes).to eq(-1)
          expect(organization_quota.total_reserved_route_ports).to eq(-1)

          expect(organization_quota.total_private_domains).to eq(-1)

          expect(organization_quota.organizations.count).to eq(0)
        end

        it 'supports associating orgs with the quota' do
          organization_quota = org_quotas_create.create(message_with_org)

          expect(organization_quota.name).to eq('my-name')
          expect(organization_quota.organizations.count).to eq(1)
          expect(organization_quota.organizations[0].guid).to eq(org.guid)
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
        context 'when the org guid is invalid' do
          let(:invalid_org_guid) { 'invalid_org_guid' }
          let(:message_with_invalid_org_guid) do
            VCAP::CloudController::OrganizationQuotasCreateMessage.new({
              'name' => 'my-name',
              'relationships' => { organizations: { data: [{ guid: invalid_org_guid }] } },
            })
          end
          it 'raises a human-friendly error' do
            expect {
              org_quotas_create.create(message_with_invalid_org_guid)
            }.to raise_error(OrganizationQuotasCreate::Error, "Organizations with guids [\"#{invalid_org_guid}\"] do not exist, or you do not have access to them.")
          end
        end
      end
    end
  end
end
