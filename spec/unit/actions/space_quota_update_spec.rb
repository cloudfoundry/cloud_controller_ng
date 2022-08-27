require 'spec_helper'
require 'actions/space_quota_update'
require 'messages/space_quota_update_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotaUpdate do
    let(:org) { VCAP::CloudController::Organization.make }

    describe 'update' do
      context 'when updating a space quota' do
        let!(:space_quota) do
          VCAP::CloudController::SpaceQuotaDefinition.make(
            name: 'space_quota_name',
            non_basic_services_allowed: true,
            organization: org
          )
        end

        let(:message) do
          VCAP::CloudController::SpaceQuotaUpdateMessage.new({
            name: 'don-quixote',
            apps: {
              total_memory_in_mb: 5120,
              per_process_memory_in_mb: 1024,
              total_instances: 8,
              per_app_tasks: nil,
              log_rate_limit_in_bytes_per_second: 2000,
            },
            services: {
              paid_services_allowed: false,
              total_service_instances: 10,
              total_service_keys: 20,
            },
            routes: {
              total_routes: 8,
              total_reserved_ports: 1
            }
          })
        end

        let(:minimum_message) do
          VCAP::CloudController::SpaceQuotaUpdateMessage.new({})
        end

        it 'updates a space quota with the given values' do
          updated_space_quota = SpaceQuotaUpdate.update(space_quota, message)

          expect(updated_space_quota.name).to eq('don-quixote')

          expect(updated_space_quota.memory_limit).to eq(5120)
          expect(updated_space_quota.instance_memory_limit).to eq(1024)
          expect(updated_space_quota.app_instance_limit).to eq(8)
          expect(updated_space_quota.app_task_limit).to eq(-1)
          expect(updated_space_quota.log_rate_limit).to eq(2000)

          expect(updated_space_quota.total_services).to eq(10)
          expect(updated_space_quota.total_service_keys).to eq(20)
          expect(updated_space_quota.non_basic_services_allowed).to eq(false)

          expect(updated_space_quota.total_reserved_route_ports).to eq(1)
          expect(updated_space_quota.total_routes).to eq(8)
        end

        it 'updates a space quota with only the given values' do
          updated_space_quota = SpaceQuotaUpdate.update(space_quota, minimum_message)

          expect(updated_space_quota.name).to eq('space_quota_name')
          expect(updated_space_quota.log_rate_limit).to eq(-1)
        end

        context 'when a model validation fails' do
          it 'raises an error' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(space_quota).to receive(:save).and_raise(Sequel::ValidationFailed.new(errors))

            message = VCAP::CloudController::SpaceQuotaUpdateMessage.new(name: 'foobar')
            expect {
              SpaceQuotaUpdate.update(space_quota, message)
            }.to raise_error(SpaceQuotaUpdate::Error, 'blork is busted')
          end

          context 'when it is a uniqueness error' do
            let(:name) { 'victoria_space_quota' }
            let!(:victoria_space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(name: name, organization: org) }
            let(:update_message) { VCAP::CloudController::SpaceQuotaUpdateMessage.new(name: name) }

            it 'raises a human-friendly error' do
              expect {
                SpaceQuotaUpdate.update(space_quota, update_message)
              }.to raise_error(SpaceQuotaUpdate::Error, "Space Quota '#{name}' already exists.")
            end
          end
        end

        context 'when there are affected processes that have an unlimited log rate limit' do
          def create_spaces_with_unlimited_log_rate_process(count)
            count.downto(1) do |i|
              space = VCAP::CloudController::Space.make(guid: "space-guid-#{i}", name: "space-name-#{i}", organization: org, space_quota_definition: space_quota)
              app_model = VCAP::CloudController::AppModel.make(name: "app-#{i}", space: space)
              VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1)
            end
          end

          context 'and they are only in a single space' do
            before do
              create_spaces_with_unlimited_log_rate_process(1)
            end
            it 'errors with a message telling the user the affected space' do
              expect do
                SpaceQuotaUpdate.update(space_quota, message)
              end.to raise_error(SpaceQuotaUpdate::Error, "Current usage exceeds new quota values. Space 'space-name-1' " \
                                 'assigned this quota contains apps running with an unlimited log rate limit.')
            end
          end

          context 'and they are in two spaces' do
            before do
              create_spaces_with_unlimited_log_rate_process(2)
            end
            it 'errors with a message telling the user the affected spaces' do
              expect do
                SpaceQuotaUpdate.update(space_quota, message)
              end.to raise_error(SpaceQuotaUpdate::Error, "Current usage exceeds new quota values. Spaces 'space-name-1', 'space-name-2' " \
                                 'assigned this quota contain apps running with an unlimited log rate limit.')
            end
          end

          context 'and they are spread across five spaces' do
            before do
              create_spaces_with_unlimited_log_rate_process(5)
            end
            it 'errors with a message telling the user some of the affected spaces and a total count' do
              expect do
                SpaceQuotaUpdate.update(space_quota, message)
              end.to raise_error(SpaceQuotaUpdate::Error, "Current usage exceeds new quota values. Spaces 'space-name-1', 'space-name-2' and 3 other spaces " \
                                 'assigned this quota contain apps running with an unlimited log rate limit.')
            end
          end

          context 'and there is more than one affected process within a space' do
            let!(:org) { VCAP::CloudController::Organization.make(guid: 'org-guid', name: 'org-name') }
            let!(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', name: 'space-name', organization: org, space_quota_definition: space_quota) }
            let!(:app_model) { VCAP::CloudController::AppModel.make(name: 'app', space: space) }
            let!(:process_1) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }
            let!(:process_2) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: -1) }

            it 'only names the space once in the error message' do
              expect do
                SpaceQuotaUpdate.update(space_quota, message)
              end.to raise_error(SpaceQuotaUpdate::Error, "Current usage exceeds new quota values. Space 'space-name' assigned this quota contains apps " \
                                                          'running with an unlimited log rate limit.')
            end
          end
        end
      end
    end
  end
end
