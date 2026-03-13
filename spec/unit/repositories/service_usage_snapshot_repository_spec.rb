require 'spec_helper'
require 'repositories/service_usage_snapshot_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe ServiceUsageSnapshotRepository do
      subject(:repository) { ServiceUsageSnapshotRepository.new }

      let(:quota) { QuotaDefinition.make(total_services: 500) }
      let(:org) { Organization.make(quota_definition: quota, name: 'test-org') }
      let(:space) { Space.make(organization: org, name: 'test-space') }
      let(:service_broker) { ServiceBroker.make(name: 'test-broker') }
      let(:service) { Service.make(service_broker: service_broker, label: 'test-service') }
      let(:service_plan) { ServicePlan.make(service: service, name: 'test-plan') }

      # Helper to create a placeholder snapshot (as the controller would)
      def create_placeholder_snapshot
        ServiceUsageSnapshot.create(
          guid: SecureRandom.uuid,
          checkpoint_event_guid: nil,
          created_at: Time.now.utc,
          completed_at: nil,
          service_instance_count: 0,
          organization_count: 0,
          space_count: 0,
          chunk_count: 0
        )
      end

      describe '#populate_snapshot!' do
        context 'when there are managed service instances' do
          let!(:instance1) { ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'instance-1') }
          let!(:instance2) { ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'instance-2') }

          it 'populates the snapshot with correct counts' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.service_instance_count).to eq(2)
            expect(snapshot.organization_count).to eq(1)
            expect(snapshot.space_count).to eq(1)
            expect(snapshot.chunk_count).to eq(1)
            expect(snapshot.completed_at).not_to be_nil
          end

          it 'creates chunk records with service instance details including V3-aligned fields' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            expect(snapshot.service_usage_snapshot_chunks.count).to eq(1)
            chunk = snapshot.service_usage_snapshot_chunks.first

            expect(chunk.space_guid).to eq(space.guid)
            expect(chunk.space_name).to eq(space.name)
            expect(chunk.organization_guid).to eq(org.guid)
            expect(chunk.organization_name).to eq(org.name)
            expect(chunk.chunk_index).to eq(0)
            expect(chunk.service_instances.size).to eq(2)
            expect(chunk.service_instances).to include(
              hash_including(
                'service_instance_guid' => instance1.guid,
                'service_instance_name' => 'instance-1',
                'service_instance_type' => 'managed',
                'service_plan_guid' => service_plan.guid,
                'service_plan_name' => 'test-plan',
                'service_offering_guid' => service.guid,
                'service_offering_name' => 'test-service',
                'service_broker_guid' => service_broker.guid,
                'service_broker_name' => 'test-broker'
              ),
              hash_including(
                'service_instance_guid' => instance2.guid,
                'service_instance_name' => 'instance-2',
                'service_instance_type' => 'managed'
              )
            )
          end

          it 'records checkpoint event GUID' do
            ServiceUsageEvent.make
            ServiceUsageEvent.make
            last_event = ServiceUsageEvent.make

            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.checkpoint_event_guid).to eq(last_event.guid)
            expect(snapshot.checkpoint_event_created_at).to be_within(1.second).of(last_event.created_at)
          end
        end

        context 'when there are user-provided service instances' do
          let!(:user_provided_instance) { UserProvidedServiceInstance.make(space: space, name: 'user-provided-1') }

          it 'includes user-provided service instance in the count' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.service_instance_count).to eq(1)
          end

          it 'marks user-provided instances correctly with nil plan/offering/broker fields' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            chunk = snapshot.service_usage_snapshot_chunks.first
            instance_data = chunk.service_instances.first

            expect(instance_data['service_instance_type']).to eq('user_provided')
            expect(instance_data['service_instance_guid']).to eq(user_provided_instance.guid)
            expect(instance_data['service_instance_name']).to eq('user-provided-1')
            expect(instance_data['service_plan_guid']).to be_nil
            expect(instance_data['service_plan_name']).to be_nil
            expect(instance_data['service_offering_guid']).to be_nil
            expect(instance_data['service_offering_name']).to be_nil
            expect(instance_data['service_broker_guid']).to be_nil
            expect(instance_data['service_broker_name']).to be_nil
          end
        end

        context 'when there are both managed and user-provided instances' do
          let!(:managed_instance) { ManagedServiceInstance.make(space:, service_plan:) }
          let!(:user_provided_instance) { UserProvidedServiceInstance.make(space:) }

          it 'includes both types in the snapshot count' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.service_instance_count).to eq(2)
          end

          it 'includes both types in chunk record' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            chunk = snapshot.service_usage_snapshot_chunks.first
            types = chunk.service_instances.pluck('service_instance_type')
            expect(types).to contain_exactly('managed', 'user_provided')
          end
        end

        context 'when there are multiple spaces' do
          let(:space2) { Space.make(organization: org) }
          let(:org2) { Organization.make }
          let(:space3) { Space.make(organization: org2) }

          before do
            ManagedServiceInstance.make(space:, service_plan:)
            ManagedServiceInstance.make(space: space2, service_plan: service_plan)
            ManagedServiceInstance.make(space: space2, service_plan: service_plan)
            ManagedServiceInstance.make(space: space3, service_plan: service_plan)
          end

          it 'creates one chunk per space' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            expect(snapshot.service_usage_snapshot_chunks.count).to eq(3)
            expect(snapshot.service_instance_count).to eq(4)
            expect(snapshot.organization_count).to eq(2)
            expect(snapshot.space_count).to eq(3)
            expect(snapshot.chunk_count).to eq(3)
          end

          it 'groups service instances by space correctly' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            chunks = snapshot.service_usage_snapshot_chunks.to_a
            space1_chunk = chunks.find { |c| c.space_guid == space.guid }
            space2_chunk = chunks.find { |c| c.space_guid == space2.guid }
            space3_chunk = chunks.find { |c| c.space_guid == space3.guid }

            expect(space1_chunk.service_instances.size).to eq(1)
            expect(space2_chunk.service_instances.size).to eq(2)
            expect(space3_chunk.service_instances.size).to eq(1)
          end
        end

        context 'when there are no service instances' do
          it 'populates snapshot with zero counts and no chunks' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.service_instance_count).to eq(0)
            expect(snapshot.organization_count).to eq(0)
            expect(snapshot.space_count).to eq(0)
            expect(snapshot.chunk_count).to eq(0)
            expect(snapshot.service_usage_snapshot_chunks.count).to eq(0)
            expect(snapshot.completed_at).not_to be_nil
          end
        end

        context 'when there are no usage events (empty system)' do
          it 'sets checkpoint_event_guid to nil and checkpoint_event_created_at to nil' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.checkpoint_event_guid).to be_nil
            expect(snapshot.checkpoint_event_created_at).to be_nil
            expect(snapshot.completed_at).not_to be_nil
          end
        end

        context 'when snapshot population fails' do
          it 'raises the error and rolls back transaction' do
            snapshot = create_placeholder_snapshot
            allow(snapshot).to receive(:update).and_raise(Sequel::DatabaseError.new('DB error'))

            prometheus = instance_double(VCAP::CloudController::Metrics::PrometheusUpdater)
            allow(CloudController::DependencyLocator.instance).to receive(:prometheus_updater).and_return(prometheus)
            expect(prometheus).to receive(:increment_counter_metric).with(:cc_service_usage_snapshot_generation_failures_total)

            expect { repository.populate_snapshot!(snapshot) }.to raise_error(Sequel::DatabaseError)
          end
        end

        context 'metrics' do
          let!(:instance) { ManagedServiceInstance.make(space:, service_plan:) }

          it 'records generation duration' do
            prometheus = instance_double(VCAP::CloudController::Metrics::PrometheusUpdater)
            allow(CloudController::DependencyLocator.instance).to receive(:prometheus_updater).and_return(prometheus)

            expect(prometheus).to receive(:update_histogram_metric).with(:cc_service_usage_snapshot_generation_duration_seconds, kind_of(Numeric))

            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)
          end
        end

        context 'edge cases' do
          context 'when exactly CHUNK_LIMIT (50) service instances in a space' do
            before do
              50.times do
                ManagedServiceInstance.make(space:, service_plan:)
              end
            end

            it 'creates exactly 1 chunk (not 2)' do
              snapshot = create_placeholder_snapshot
              repository.populate_snapshot!(snapshot)

              expect(snapshot.service_usage_snapshot_chunks.count).to eq(1)
              expect(snapshot.service_instance_count).to eq(50)
              expect(snapshot.chunk_count).to eq(1)

              chunk = snapshot.service_usage_snapshot_chunks.first
              expect(chunk.chunk_index).to eq(0)
              expect(chunk.service_instances.size).to eq(50)
            end
          end

          context 'when exactly CHUNK_LIMIT + 1 (51) service instances in a space' do
            before do
              51.times do
                ManagedServiceInstance.make(space:, service_plan:)
              end
            end

            it 'creates exactly 2 chunks (50 + 1)' do
              snapshot = create_placeholder_snapshot
              repository.populate_snapshot!(snapshot)

              expect(snapshot.service_usage_snapshot_chunks.count).to eq(2)
              expect(snapshot.service_instance_count).to eq(51)
              expect(snapshot.chunk_count).to eq(2)

              chunks = snapshot.service_usage_snapshot_chunks_dataset.order(:chunk_index).to_a
              expect(chunks[0].service_instances.size).to eq(50)
              expect(chunks[1].service_instances.size).to eq(1)
            end
          end

          context 'when a space has many service instances (chunking test)' do
            before do
              75.times do
                ManagedServiceInstance.make(space:, service_plan:)
              end
            end

            it 'creates multiple chunks for the same space' do
              snapshot = create_placeholder_snapshot
              repository.populate_snapshot!(snapshot)

              # 75 instances should create 2 chunks (50 + 25)
              expect(snapshot.service_usage_snapshot_chunks.count).to eq(2)
              expect(snapshot.service_instance_count).to eq(75)
              expect(snapshot.chunk_count).to eq(2)

              chunks = snapshot.service_usage_snapshot_chunks_dataset.order(:chunk_index).to_a
              expect(chunks[0].chunk_index).to eq(0)
              expect(chunks[0].service_instances.size).to eq(50)
              expect(chunks[1].chunk_index).to eq(1)
              expect(chunks[1].service_instances.size).to eq(25)
            end
          end

          context 'when transaction fails mid-way' do
            it 'rolls back all chunks (atomic operation)' do
              ManagedServiceInstance.make(space:, service_plan:)

              snapshot = create_placeholder_snapshot
              initial_chunk_count = ServiceUsageSnapshotChunk.count

              # Simulate failure during final update within the transaction
              allow(snapshot).to receive(:update).and_raise(Sequel::DatabaseError.new('DB error'))

              prometheus = instance_double(VCAP::CloudController::Metrics::PrometheusUpdater)
              allow(CloudController::DependencyLocator.instance).to receive(:prometheus_updater).and_return(prometheus)
              allow(prometheus).to receive(:increment_counter_metric)

              expect { repository.populate_snapshot!(snapshot) }.to raise_error(Sequel::DatabaseError)

              # Verify no orphan chunks were created (transaction rolled back)
              expect(ServiceUsageSnapshotChunk.count).to eq(initial_chunk_count)
            end
          end
        end
      end
    end
  end
end
