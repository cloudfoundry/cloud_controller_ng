require 'spec_helper'

module VCAP::CloudController
  module Jobs
    module Runtime
      RSpec.describe ServiceUsageSnapshotGeneratorJob do
        let(:snapshot) { ServiceUsageSnapshot.make(service_instance_count: 50, completed_at: nil) }
        subject(:job) { ServiceUsageSnapshotGeneratorJob.new(snapshot.guid) }

        let(:repository) { instance_double(Repositories::ServiceUsageSnapshotRepository) }

        before do
          allow(Repositories::ServiceUsageSnapshotRepository).to receive(:new).and_return(repository)
        end

        describe '#initialize' do
          it 'sets resource_guid from the constructor argument' do
            expect(job.resource_guid).to eq(snapshot.guid)
          end
        end

        describe '#perform' do
          before do
            allow(repository).to receive(:populate_snapshot!)
          end

          it 'fetches the snapshot and calls the repository to populate it' do
            expect(repository).to receive(:populate_snapshot!).with(snapshot)

            job.perform
          end

          it 'logs the start and completion' do
            allow(repository).to receive(:populate_snapshot!) do |s|
              s.update(service_instance_count: 50, completed_at: Time.now.utc)
            end

            logger = instance_double(Steno::Logger)
            allow(Steno).to receive(:logger).with('cc.background').and_return(logger)

            expect(logger).to receive(:info).with("Starting service usage snapshot generation for snapshot #{snapshot.guid}")
            expect(logger).to receive(:info).with("Service usage snapshot #{snapshot.guid} completed: 50 service instances")

            job.perform
          end

          context 'when snapshot is not found' do
            subject(:job) { ServiceUsageSnapshotGeneratorJob.new('non-existent-guid') }

            it 'raises an error' do
              expect { job.perform }.to raise_error(RuntimeError, /Snapshot not found: non-existent-guid/)
            end
          end

          context 'when population fails' do
            let(:error) { StandardError.new('Database connection failed') }

            before do
              allow(repository).to receive(:populate_snapshot!).and_raise(error)
            end

            it 'logs the error with backtrace' do
              logger = instance_double(Steno::Logger)
              allow(Steno).to receive(:logger).with('cc.background').and_return(logger)

              expect(logger).to receive(:info).with("Starting service usage snapshot generation for snapshot #{snapshot.guid}")
              expect(logger).to receive(:error).with(/Service usage snapshot generation failed: Database connection failed/)

              expect { job.perform }.to raise_error(StandardError, 'Database connection failed')
            end

            it 're-raises the error' do
              expect { job.perform }.to raise_error(StandardError, 'Database connection failed')
            end
          end
        end

        describe '#job_name_in_configuration' do
          it 'returns the correct job name' do
            expect(job.job_name_in_configuration).to eq(:service_usage_snapshot_generator)
          end
        end

        describe '#max_attempts' do
          it 'returns 1' do
            expect(job.max_attempts).to eq(1)
          end
        end

        describe '#resource_type' do
          it 'returns service_usage_snapshot' do
            expect(job.resource_type).to eq('service_usage_snapshot')
          end
        end

        describe '#display_name' do
          it 'returns the display name' do
            expect(job.display_name).to eq('service_usage_snapshot.generate')
          end
        end
      end
    end
  end
end
