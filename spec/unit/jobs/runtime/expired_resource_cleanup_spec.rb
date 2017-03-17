require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe ExpiredResourceCleanup do
      subject(:job) { described_class.new }

      it { is_expected.to be_a_valid_job }

      it 'has max_attempts 1' do
        expect(job.max_attempts).to eq 1
      end

      describe 'droplets' do
        context 'expired' do
          it 'deletes droplets that are expired and have no checksum information' do
            droplet = DropletModel.make(state: DropletModel::EXPIRED_STATE, droplet_hash: nil, sha256_checksum: nil)

            expect { job.perform }.to change { DropletModel.count }.by(-1)
            expect(droplet).to_not exist
          end

          it 'does NOT delete droplets that are expired and has only a sha1 checksum' do
            droplet = DropletModel.make(state: DropletModel::EXPIRED_STATE, droplet_hash: 'foo', sha256_checksum: nil)

            expect { job.perform }.to_not change { DropletModel.count }
            expect(droplet).to exist
          end

          it 'does NOT delete droplets that are expired and has only a sha256 checksum' do
            droplet = DropletModel.make(state: DropletModel::EXPIRED_STATE, droplet_hash: nil, sha256_checksum: 'foo')

            expect { job.perform }.to_not change { DropletModel.count }
            expect(droplet).to exist
          end

          it 'does NOT delete droplets that are NOT expired' do
            droplet = DropletModel.make(:staged)

            job.perform
            expect(droplet).to exist
          end
        end
      end

      describe 'packages' do
        context 'expired' do
          let!(:expired_deleted_package) { PackageModel.make(state: PackageModel::EXPIRED_STATE, package_hash: nil) }
          let!(:expired_not_deleted_package) { PackageModel.make(state: PackageModel::EXPIRED_STATE, package_hash: 'not-nil') }
          let!(:non_expired_package) { PackageModel.make(:staged) }

          it 'deletes packages that are expired and have nil package_hash' do
            expect { job.perform }.to change { PackageModel.count }.by(-1)
            expect(expired_deleted_package).to_not exist
          end

          it 'does NOT delete packages that are expired but have a package_hash' do
            job.perform
            expect(expired_not_deleted_package).to exist
          end

          it 'does NOT delete packages that are NOT expired' do
            job.perform
            expect(non_expired_package).to exist
          end
        end
      end
    end
  end
end
