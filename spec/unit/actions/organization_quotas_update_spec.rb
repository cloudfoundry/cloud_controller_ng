require 'spec_helper'
require 'actions/organization_quotas_update'
require 'messages/organization_quotas_update_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotasUpdate do
    describe 'update' do
      context 'when updating an organization quota' do
        let!(:org_quota) { VCAP::CloudController::QuotaDefinition.make(name: 'org_quota_name', non_basic_services_allowed: true) }

        let(:message) do
          VCAP::CloudController::OrganizationQuotasUpdateMessage.new({
              name: 'don-quixote',
              apps: {
                total_memory_in_mb: 5120,
                per_process_memory_in_mb: 1024,
                total_instances: 8,
                per_app_tasks: nil,
                log_rate_limit_in_bytes_per_second: 2000
              },
              services: {
                paid_services_allowed: false,
                total_service_instances: 10,
                total_service_keys: 20,
              },
              routes: {
                total_routes: 8,
                total_reserved_ports: 6
              },
              domains: {
                total_domains: 7
              }
          })
        end

        let(:minimum_message) do
          VCAP::CloudController::OrganizationQuotasCreateMessage.new({
            domains: {
                total_private_domains: 7
              }
          })
        end

        it 'updates an organization quota with the given values' do
          updated_organization_quota = OrganizationQuotasUpdate.update(org_quota, message)

          expect(updated_organization_quota.name).to eq('don-quixote')

          expect(updated_organization_quota.memory_limit).to eq(5120)
          expect(updated_organization_quota.instance_memory_limit).to eq(1024)
          expect(updated_organization_quota.app_instance_limit).to eq(8)
          expect(updated_organization_quota.app_task_limit).to eq(-1)
          expect(updated_organization_quota.log_rate_limit).to eq(2000)

          expect(updated_organization_quota.total_services).to eq(10)
          expect(updated_organization_quota.total_service_keys).to eq(20)
          expect(updated_organization_quota.non_basic_services_allowed).to eq(false)

          expect(updated_organization_quota.total_reserved_route_ports).to eq(6)
          expect(updated_organization_quota.total_routes).to eq(8)

          expect(updated_organization_quota.total_private_domains).to eq(7)
        end

        it 'updates an organization quota with only the given values' do
          updated_organization_quota = OrganizationQuotasUpdate.update(org_quota, minimum_message)

          expect(updated_organization_quota.name).to eq('org_quota_name')
          expect(updated_organization_quota.log_rate_limit).to eq(-1)
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(org_quota).to receive(:save).
              and_raise(Sequel::ValidationFailed.new(errors))

            message = VCAP::CloudController::OrganizationQuotasCreateMessage.new(name: 'foobar')
            expect {
              OrganizationQuotasUpdate.update(org_quota, message)
            }.to raise_error(OrganizationQuotasUpdate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:victoria_org_quota) { VCAP::CloudController::QuotaDefinition.make(name: 'victoria_org_quota') }

            let(:name) { 'victoria_org_quota' }
            let(:update_message) { VCAP::CloudController::OrganizationQuotasUpdateMessage.new(name: name) }

            let(:create_message) { VCAP::CloudController::OrganizationQuotasCreateMessage.new(name: name) }

            let(:org_quotas_create) { OrganizationQuotasCreate.new }

            before do
              org_quotas_create.create(create_message)
            end

            it 'raises a human-friendly error' do
              expect {
                OrganizationQuotasUpdate.update(org_quota, update_message)
              }.to raise_error(OrganizationQuotasUpdate::Error, "Organization Quota '#{name}' already exists.")
            end
          end
        end

        context 'when there are affected processes that have an unlimited log rate limit' do
          def create_orgs_with_unlimited_log_rate_process(count)
            count.downto(1) do |i|
              org = VCAP::CloudController::Organization.make(guid: "org-guid-#{i}", name: "org-name-#{i}", quota_definition: org_quota)
              space = VCAP::CloudController::Space.make(guid: "space-guid-#{i}", organization: org)
              app_model = VCAP::CloudController::AppModel.make(name: "app-#{i}", space: space)
              VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1)
            end
          end

          context 'and they are only in a single org' do
            before do
              create_orgs_with_unlimited_log_rate_process(1)
            end
            it 'errors with a message telling the user the affected org' do
              expect do
                OrganizationQuotasUpdate.update(org_quota, message)
              end.to raise_error(OrganizationQuotasUpdate::Error, "Current usage exceeds new quota values. Org 'org-name-1' " \
                                 'assigned this quota contains apps running with an unlimited log rate limit.')
            end
          end
          context 'and they are in two orgs' do
            before do
              create_orgs_with_unlimited_log_rate_process(2)
            end
            it 'errors with a message telling the user the affected orgs' do
              expect do
                OrganizationQuotasUpdate.update(org_quota, message)
              end.to raise_error(OrganizationQuotasUpdate::Error, "Current usage exceeds new quota values. Orgs 'org-name-1', 'org-name-2' " \
                                 'assigned this quota contain apps running with an unlimited log rate limit.')
            end
          end

          context 'and they are spread across five orgs' do
            before do
              create_orgs_with_unlimited_log_rate_process(5)
            end
            it 'errors with a message telling the user some of the affected orgs and a total count' do
              expect do
                OrganizationQuotasUpdate.update(org_quota, message)
              end.to raise_error(OrganizationQuotasUpdate::Error, "Current usage exceeds new quota values. Orgs 'org-name-1', 'org-name-2' and 3 other orgs " \
                                 'assigned this quota contain apps running with an unlimited log rate limit.')
            end
          end

          context 'and there is more than one affected process within an org' do
            let(:org) { VCAP::CloudController::Organization.make(guid: 'org-guid', name: 'org-name', quota_definition: org_quota) }
            let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', organization: org) }
            let(:app_model) { VCAP::CloudController::AppModel.make(name: 'app', space: space) }
            let!(:process_1) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }
            let!(:process_2) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }

            it 'only names the org once in the error message' do
              expect do
                OrganizationQuotasUpdate.update(org_quota, message)
              end.to raise_error(OrganizationQuotasUpdate::Error, "Current usage exceeds new quota values. Org 'org-name' assigned this quota contains apps " \
                                                                  'running with an unlimited log rate limit.')
            end
          end
        end
      end
    end
  end
end
