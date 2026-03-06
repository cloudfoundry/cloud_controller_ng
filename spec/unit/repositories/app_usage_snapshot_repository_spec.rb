require 'spec_helper'
require 'repositories/app_usage_snapshot_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe AppUsageSnapshotRepository do
      subject(:repository) { AppUsageSnapshotRepository.new }

      let(:org) { Organization.make(name: 'test-org') }
      let(:space) { Space.make(organization: org, name: 'test-space') }
      let(:app_model) { AppModel.make(space: space, name: 'test-app') }

      def create_placeholder_snapshot
        AppUsageSnapshot.create(
          guid: SecureRandom.uuid,
          checkpoint_event_guid: nil,
          created_at: Time.now.utc,
          completed_at: nil,
          instance_count: 0,
          organization_count: 0,
          space_count: 0,
          app_count: 0,
          chunk_count: 0
        )
      end

      describe '#populate_snapshot!' do
        context 'when there are running processes' do
          let!(:process1) { ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 3, memory: 256, type: 'web') }
          let!(:process2) { ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 2, memory: 512, type: 'worker') }
          let!(:stopped_process) { ProcessModel.make(app: app_model, state: ProcessModel::STOPPED, instances: 1) }

          it 'populates the snapshot with correct counts' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            # 3 instances (web) + 2 instances (worker) = 5 total instances
            expect(snapshot.instance_count).to eq(5)
            expect(snapshot.app_count).to eq(1) # both processes belong to same app
            expect(snapshot.organization_count).to eq(1)
            expect(snapshot.space_count).to eq(1)
            expect(snapshot.chunk_count).to eq(1)
            expect(snapshot.completed_at).not_to be_nil
          end

          it 'creates chunk records with process details including V3-aligned fields' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            expect(snapshot.app_usage_snapshot_chunks.count).to eq(1)
            chunk = snapshot.app_usage_snapshot_chunks.first

            expect(chunk.space_guid).to eq(space.guid)
            expect(chunk.space_name).to eq(space.name)
            expect(chunk.organization_guid).to eq(org.guid)
            expect(chunk.organization_name).to eq(org.name)
            expect(chunk.chunk_index).to eq(0)
            expect(chunk.processes).to contain_exactly(
              hash_including(
                'app_guid' => app_model.guid,
                'app_name' => app_model.name,
                'process_guid' => process1.guid,
                'process_type' => 'web',
                'instance_count' => 3,
                'memory_in_mb_per_instance' => 256
              ),
              hash_including(
                'app_guid' => app_model.guid,
                'app_name' => app_model.name,
                'process_guid' => process2.guid,
                'process_type' => 'worker',
                'instance_count' => 2,
                'memory_in_mb_per_instance' => 512
              )
            )
          end

          it 'records checkpoint event GUID' do
            AppUsageEvent.make
            AppUsageEvent.make
            last_event = AppUsageEvent.make

            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.checkpoint_event_guid).to eq(last_event.guid)
            expect(snapshot.checkpoint_event_created_at).to be_within(1.second).of(last_event.created_at)
          end

          it 'excludes task and build processes from counts' do
            ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 10, type: 'TASK')
            ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 5, type: 'build')

            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            # Only web (3) + worker (2) = 5 instances, 1 app
            expect(snapshot.instance_count).to eq(5)
            expect(snapshot.app_count).to eq(1)
          end
        end

        context 'when there are multiple spaces' do
          let(:space2) { Space.make(organization: org) }
          let(:org2) { Organization.make }
          let(:space3) { Space.make(organization: org2) }
          let(:app_model2) { AppModel.make(space: space2) }
          let(:app_model3) { AppModel.make(space: space3) }

          before do
            ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 2, type: 'web')
            ProcessModel.make(app: app_model2, state: ProcessModel::STARTED, instances: 3, type: 'web')
            ProcessModel.make(app: app_model3, state: ProcessModel::STARTED, instances: 5, type: 'web')
          end

          it 'creates one chunk per space' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            expect(snapshot.app_usage_snapshot_chunks.count).to eq(3)
            expect(snapshot.instance_count).to eq(10) # 2 + 3 + 5
            expect(snapshot.app_count).to eq(3)
            expect(snapshot.organization_count).to eq(2)
            expect(snapshot.space_count).to eq(3)
            expect(snapshot.chunk_count).to eq(3)
          end

          it 'groups processes by space correctly' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            chunks = snapshot.app_usage_snapshot_chunks.to_a
            space1_chunk = chunks.find { |c| c.space_guid == space.guid }
            space2_chunk = chunks.find { |c| c.space_guid == space2.guid }
            space3_chunk = chunks.find { |c| c.space_guid == space3.guid }

            expect(space1_chunk.processes.size).to eq(1)
            expect(space2_chunk.processes.size).to eq(1)
            expect(space3_chunk.processes.size).to eq(1)
          end
        end

        context 'when a space has many processes (chunking test)' do
          # Create more than CHUNK_LIMIT (50) processes in one space
          before do
            75.times do |_i|
              process_app = AppModel.make(space:)
              ProcessModel.make(app: process_app, state: ProcessModel::STARTED, instances: 1, type: 'web')
            end
          end

          it 'creates multiple chunks for the same space' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            # 75 processes should create 2 chunks (50 + 25)
            expect(snapshot.app_usage_snapshot_chunks.count).to eq(2)
            expect(snapshot.app_count).to eq(75)
            expect(snapshot.instance_count).to eq(75)
            expect(snapshot.chunk_count).to eq(2)

            chunks = snapshot.app_usage_snapshot_chunks_dataset.order(:chunk_index).to_a
            expect(chunks[0].chunk_index).to eq(0)
            expect(chunks[0].processes.size).to eq(50)
            expect(chunks[1].chunk_index).to eq(1)
            expect(chunks[1].processes.size).to eq(25)
          end
        end

        context 'when there are no running processes' do
          it 'populates snapshot with zero counts and no chunks' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            snapshot.reload
            expect(snapshot.instance_count).to eq(0)
            expect(snapshot.app_count).to eq(0)
            expect(snapshot.organization_count).to eq(0)
            expect(snapshot.space_count).to eq(0)
            expect(snapshot.chunk_count).to eq(0)
            expect(snapshot.app_usage_snapshot_chunks.count).to eq(0)
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

        context 'when app has a droplet with buildpack information' do
          let(:droplet) do
            DropletModel.make(
              app: app_model,
              state: DropletModel::STAGED_STATE,
              buildpack_receipt_buildpack_guid: 'buildpack-guid-123',
              buildpack_receipt_buildpack: 'ruby_buildpack'
            )
          end

          before do
            app_model.update(droplet:)
            ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 2, memory: 1024, type: 'web')
          end

          it 'includes buildpack information in the process JSON' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            chunk = snapshot.app_usage_snapshot_chunks.first
            process_data = chunk.processes.first

            expect(process_data['buildpack_guid']).to eq('buildpack-guid-123')
            expect(process_data['buildpack_name']).to eq('ruby_buildpack')
          end
        end

        context 'when app does not have a droplet' do
          let!(:process) { ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 2, type: 'web') }

          it 'includes nil for buildpack fields' do
            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)

            chunk = snapshot.app_usage_snapshot_chunks.first
            process_data = chunk.processes.first

            expect(process_data['buildpack_guid']).to be_nil
            expect(process_data['buildpack_name']).to be_nil
          end
        end

        context 'when snapshot population fails' do
          it 'raises the error and rolls back transaction' do
            snapshot = create_placeholder_snapshot
            allow(snapshot).to receive(:update).and_raise(Sequel::DatabaseError.new('DB error'))

            prometheus = instance_double(VCAP::CloudController::Metrics::PrometheusUpdater)
            allow(CloudController::DependencyLocator.instance).to receive(:prometheus_updater).and_return(prometheus)
            expect(prometheus).to receive(:increment_counter_metric).with(:cc_app_usage_snapshot_generation_failures_total)

            expect { repository.populate_snapshot!(snapshot) }.to raise_error(Sequel::DatabaseError)
          end
        end

        context 'metrics' do
          it 'records generation duration' do
            prometheus = instance_double(VCAP::CloudController::Metrics::PrometheusUpdater)
            allow(CloudController::DependencyLocator.instance).to receive(:prometheus_updater).and_return(prometheus)

            expect(prometheus).to receive(:update_histogram_metric).with(:cc_app_usage_snapshot_generation_duration_seconds, anything)

            snapshot = create_placeholder_snapshot
            repository.populate_snapshot!(snapshot)
          end

          it 'increments failure counter on error' do
            prometheus = instance_double(VCAP::CloudController::Metrics::PrometheusUpdater)
            allow(CloudController::DependencyLocator.instance).to receive(:prometheus_updater).and_return(prometheus)

            snapshot = create_placeholder_snapshot
            allow(snapshot).to receive(:update).and_raise(StandardError.new('test error'))

            expect(prometheus).to receive(:increment_counter_metric).with(:cc_app_usage_snapshot_generation_failures_total)

            expect { repository.populate_snapshot!(snapshot) }.to raise_error(StandardError)
          end
        end

        context 'edge cases' do
          context 'when exactly CHUNK_LIMIT (50) processes in a space' do
            before do
              50.times do
                process_app = AppModel.make(space:)
                ProcessModel.make(app: process_app, state: ProcessModel::STARTED, instances: 1, type: 'web')
              end
            end

            it 'creates exactly 1 chunk (not 2)' do
              snapshot = create_placeholder_snapshot
              repository.populate_snapshot!(snapshot)

              expect(snapshot.app_usage_snapshot_chunks.count).to eq(1)
              expect(snapshot.app_count).to eq(50)
              expect(snapshot.chunk_count).to eq(1)

              chunk = snapshot.app_usage_snapshot_chunks.first
              expect(chunk.chunk_index).to eq(0)
              expect(chunk.processes.size).to eq(50)
            end
          end

          context 'when exactly CHUNK_LIMIT + 1 (51) processes in a space' do
            before do
              51.times do
                process_app = AppModel.make(space:)
                ProcessModel.make(app: process_app, state: ProcessModel::STARTED, instances: 1, type: 'web')
              end
            end

            it 'creates exactly 2 chunks (50 + 1)' do
              snapshot = create_placeholder_snapshot
              repository.populate_snapshot!(snapshot)

              expect(snapshot.app_usage_snapshot_chunks.count).to eq(2)
              expect(snapshot.app_count).to eq(51)
              expect(snapshot.chunk_count).to eq(2)

              chunks = snapshot.app_usage_snapshot_chunks_dataset.order(:chunk_index).to_a
              expect(chunks[0].processes.size).to eq(50)
              expect(chunks[1].processes.size).to eq(1)
            end
          end

          context 'when transaction fails mid-way' do
            it 'rolls back all chunks (atomic operation)' do
              ProcessModel.make(app: app_model, state: ProcessModel::STARTED, instances: 3, type: 'web')

              snapshot = create_placeholder_snapshot
              initial_chunk_count = AppUsageSnapshotChunk.count

              # Simulate failure during final update within the transaction
              allow(snapshot).to receive(:update).and_raise(Sequel::DatabaseError.new('DB error'))

              prometheus = instance_double(VCAP::CloudController::Metrics::PrometheusUpdater)
              allow(CloudController::DependencyLocator.instance).to receive(:prometheus_updater).and_return(prometheus)
              allow(prometheus).to receive(:increment_counter_metric)

              expect { repository.populate_snapshot!(snapshot) }.to raise_error(Sequel::DatabaseError)

              # Verify no orphan chunks were created (transaction rolled back)
              expect(AppUsageSnapshotChunk.count).to eq(initial_chunk_count)
            end
          end
        end
      end
    end
  end
end
