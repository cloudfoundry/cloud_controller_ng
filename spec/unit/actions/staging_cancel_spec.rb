require 'spec_helper'
require 'actions/staging_cancel'

module VCAP::CloudController
  RSpec.describe StagingCancel do
    subject(:cancel_action) { StagingCancel.new(stagers) }
    let(:stagers) { instance_double(Stagers) }
    let(:stager) { instance_double(Diego::Stager) }
    let(:usage_event_repo) { instance_double(Repositories::AppUsageEventRepository, create_from_build: nil) }

    before do
      allow(stagers).to receive(:stager_for_app).and_return(stager)
      allow(stager).to receive(:stop_stage)
      allow(Repositories::AppUsageEventRepository).to receive(:new).and_return(usage_event_repo)
    end

    describe '#cancel' do
      context 'when the build is staging' do
        let!(:build) { BuildModel.make(state: BuildModel::STAGING_STATE) }

        it 'sends a stop staging request' do
          cancel_action.cancel([build])
          expect(stager).to have_received(:stop_stage).with(build.guid)
        end
      end

      context 'when the build is in a terminal state' do
        let!(:build) { BuildModel.make(state: BuildModel::FAILED_STATE) }

        it 'does NOT send a stop staging request' do
          cancel_action.cancel([build])
          expect(stager).not_to have_received(:stop_stage).with(build.guid)
        end
      end
    end
  end
end
