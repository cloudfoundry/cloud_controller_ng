require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe ExpiredBlobCleanup, job_context: :worker do
      subject(:job) { ExpiredBlobCleanup.new }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:expired_blob_cleanup)
      end

      describe 'droplets' do
        let!(:buildpack_droplet) { DropletModel.make(droplet_hash: 'not-nil', docker_receipt_image: nil) }
        let!(:docker_droplet) { DropletModel.make(droplet_hash: nil, docker_receipt_image: 'repo/test-app') }
        let!(:staged_droplet) { DropletModel.make(state: DropletModel::STAGED_STATE) }

        context 'expired' do
          before do
            buildpack_droplet.update(state: DropletModel::EXPIRED_STATE)
            docker_droplet.update(state: DropletModel::EXPIRED_STATE)
          end

          it 'enqueues a deletion job only for buildpack droplets' do
            expect { job.perform }.to change { Delayed::Job.count }.by(1)
            expect(Delayed::Job.last.handler).to include('DeleteExpiredDropletBlob')
          end
        end

        context 'failed' do
          before do
            buildpack_droplet.update(state: DropletModel::FAILED_STATE)
            docker_droplet.update(state: DropletModel::FAILED_STATE)
          end

          it 'enqueues a deletion job only for buildpack droplets' do
            expect { job.perform }.to change { Delayed::Job.count }.by(1)
            expect(Delayed::Job.last.handler).to include('DeleteExpiredDropletBlob')
          end
        end
      end

      describe 'packages' do
        context 'expired' do
          let!(:expired_package) { PackageModel.make(state: PackageModel::EXPIRED_STATE) }
          let!(:non_expired_package) { PackageModel.make(state: PackageModel::READY_STATE, package_hash: 'not-nil') }

          it 'enqueues a deletion job when package_hash is not nil' do
            expired_package.update(package_hash: 'not-nil')

            expect { job.perform }.to change { Delayed::Job.count }.by(1)
            expect(Delayed::Job.last.handler).to include('DeleteExpiredPackageBlob')
          end

          it 'enqueues a deletion job when only package_hash is nil' do
            expired_package.update(package_hash: nil)

            expect { job.perform }.to change { Delayed::Job.count }.by(1)
            expect(Delayed::Job.last.handler).to include('DeleteExpiredPackageBlob')
          end

          it 'does nothing when both package_hash and sha256_checksum are blank' do
            expired_package.update(package_hash: nil, sha256_checksum: '')

            expect { job.perform }.not_to change { Delayed::Job.count }.from(0)
          end
        end
      end
    end
  end
end
