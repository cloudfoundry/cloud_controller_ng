require 'spec_helper'
require 'actions/space_quota_update'
require 'messages/space_quota_update_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotaUpdate do
    let(:org) { VCAP::CloudController::Organization.make }

    describe 'update' do
      context 'when updating an organization quota' do
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
              per_app_tasks: nil
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

        it 'updates an organization quota with the given values' do
          updated_space_quota = SpaceQuotaUpdate.update(space_quota, message)

          expect(updated_space_quota.name).to eq('don-quixote')

          expect(updated_space_quota.memory_limit).to eq(5120)
          expect(updated_space_quota.instance_memory_limit).to eq(1024)
          expect(updated_space_quota.app_instance_limit).to eq(8)
          expect(updated_space_quota.app_task_limit).to eq(-1)

          expect(updated_space_quota.total_services).to eq(10)
          expect(updated_space_quota.total_service_keys).to eq(20)
          expect(updated_space_quota.non_basic_services_allowed).to eq(false)

          expect(updated_space_quota.total_reserved_route_ports).to eq(1)
          expect(updated_space_quota.total_routes).to eq(8)
        end

        it 'updates an organization quota with only the given values' do
          updated_space_quota = SpaceQuotaUpdate.update(space_quota, minimum_message)

          expect(updated_space_quota.name).to eq('space_quota_name')
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
      end
    end
  end
end
