require 'spec_helper'
require 'actions/build_delete'

module VCAP::CloudController
  RSpec.describe BuildDelete do
    let(:stagers) { instance_double(Stagers) }

    subject(:build_delete) { BuildDelete.new(stagers) }

    describe '#delete' do
      let!(:build) { BuildModel.make }

      it 'deletes the build record' do
        expect {
          build_delete.delete([build])
        }.to change { BuildModel.count }.by(-1)
        expect { build.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'cancelling staging' do
        let(:stager) { instance_double(Diego::Stager) }

        before do
          allow(stagers).to receive(:stager_for_app).and_return(stager)
          allow(stager).to receive(:stop_stage)
        end

        context 'when the build is staging' do
          let!(:build) { BuildModel.make(state: BuildModel::STAGING_STATE) }

          it 'sends a stop staging request' do
            build_delete.delete([build])
            expect(stagers).to have_received(:stager_for_app).with(build.app)
            expect(stager).to have_received(:stop_stage).with(build.guid)
          end
        end

        context 'when the build is in a terminal state' do
          let!(:build) { BuildModel.make(state: BuildModel::FAILED_STATE) }

          it 'does NOT send a stop staging request' do
            build_delete.delete([build])
            expect(stagers).not_to have_received(:stager_for_app).with(build.app)
            expect(stager).not_to have_received(:stop_stage).with(build.guid)
          end
        end
      end
    end
  end
end
