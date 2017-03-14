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
          let!(:expired_deleted_droplet) { DropletModel.make(state: DropletModel::EXPIRED_STATE, droplet_hash: nil) }
          let!(:expired_not_deleted_droplet) { DropletModel.make(state: DropletModel::EXPIRED_STATE, droplet_hash: 'not-nil') }
          let!(:non_expired_droplet) { DropletModel.make(:staged) }

          it 'deletes droplets that are expired and have nil droplet_hash' do
            expect { job.perform }.to change { DropletModel.count }.by(-1)
            expect(expired_deleted_droplet).to_not exist
          end

          it 'does NOT delete droplets that are expired but have a droplet_hash' do
            job.perform
            expect(expired_not_deleted_droplet).to exist
          end

          it 'does NOT delete droplets that are NOT expired' do
            job.perform
            expect(non_expired_droplet).to exist
          end
        end
      end
    end
  end
end
