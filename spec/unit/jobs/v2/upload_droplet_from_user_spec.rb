require 'spec_helper'

module VCAP::CloudController
  module Jobs::V2
    RSpec.describe UploadDropletFromUser do
      let(:app) { AppModel.make }
      let(:droplet) { DropletModel.make(app: app) }

      subject(:job) { described_class.new('file_path', droplet.guid) }

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        before do
          allow_any_instance_of(Jobs::V3::DropletUpload).to receive(:perform)
        end

        it 'delegates to the V3::DropletUpload job to put the file in the blobstore' do
          expect_any_instance_of(Jobs::V3::DropletUpload).to receive(:perform)
          job.perform
        end

        it 'marks the droplet as STAGED' do
          expect(droplet.staged?).to be_falsey
          job.perform
          expect(droplet.reload.staged?).to be_truthy
        end

        it 'sets the droplet as the current droplet for the app' do
          expect(app.droplet).to be_nil
          job.perform
          expect(app.reload.droplet.guid).to eq(droplet.guid)
        end

        context 'when the droplet is gone' do
          before do
            droplet.destroy
          end

          it 'does not raise an error' do
            expect { job.perform }.not_to raise_error
          end
        end
      end
    end
  end
end
