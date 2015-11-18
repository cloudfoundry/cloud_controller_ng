require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe OrphanedDropletsCleanup do
      let(:cutoff_age_in_days) { 1 }
      let(:tmp_dir) { Dir.mktmpdir }
      let(:droplet_files) { droplet_blobstore.files }
      let(:droplet_blobstore) do
        opts = { provider: 'Local', local_root: Dir.mktmpdir }
        CloudController::Blobstore::Client.new(opts, 'droplet')
      end
      let(:droplet_zip) do
        Tempfile.new('droplet_zip').path.tap do |dst|
          src = File.expand_path('../../../../fixtures/good.zip', __FILE__)
          FileUtils.cp(src, dst)
        end
      end

      subject(:job) { OrphanedDropletsCleanup.new(cutoff_age_in_days) }

      it { is_expected.to be_a_valid_job }

      before do
        Fog.unmock!
        allow(CloudController::DependencyLocator.instance).
          to receive(:droplet_blobstore).and_return(droplet_blobstore)
        Timecop.freeze(Time.now + 2.day)
      end

      after do
        Timecop.return
        Fog.mock!
      end

      context 'given a v2 app with uploaded droplet' do
        let!(:app) do
          VCAP::CloudController::AppFactory.make.tap do |app|
            u = CloudController::DropletUploader.new(app, droplet_blobstore)
            u.upload(droplet_zip)
          end
        end

        context 'when app is destroyed' do
          before { app.destroy }

          it 'removes orphaned blobs which are older then cutoff_age_in_days' do
            expect { job.perform }.to change { droplet_files.reload }.to([])
          end

          context 'with cutoff_age greater then blob age' do
            let(:cutoff_age_in_days) { 3 }

            it 'skips recently orphaned blobs' do
              expect { job.perform }.to_not change { droplet_files.reload }
              expect(droplet_files.reload.size).to eq 1
            end
          end
        end

        it 'skips blobs which belong to an application' do
          expect { job.perform }.to_not change { droplet_files.reload }
          expect(droplet_files.reload.size).to eq 1
        end
      end

      context 'given a v3 droplet' do
        let!(:droplet) do
          VCAP::CloudController::DropletModel.create(
            state: VCAP::CloudController::DropletModel::STAGED_STATE
          ).tap do |droplet|
            VCAP::CloudController::Jobs::V3::DropletUpload.new(
              droplet_zip, droplet.guid
            ).perform
          end
        end

        context 'when droplet is destroyed' do
          before do
            droplet.destroy
          end

          it 'removes orphaned blobs which are older then cutoff_age_in_days' do
            expect { job.perform }.to change { droplet_files.reload }.to([])
          end

          context 'with cutoff_age greater then blob age' do
            let(:cutoff_age_in_days) { 3 }

            it 'skips recently orphaned blobs' do
              expect { job.perform }.to_not change { droplet_files.reload }
              expect(droplet_files.reload.size).to eq 1
            end
          end
        end

        it 'skips blobs which belong to an application' do
          expect { job.perform }.to_not change { droplet_files.reload }
          expect(droplet_files.reload.size).to eq 1
        end
      end

      context 'given an blob with an unexpected key' do
        before do
          droplet_blobstore.cp_to_blobstore(
            droplet_zip,
            '719640e5-c951-4029-8ffe-a9c6eb17bf61/' \
            '00000000000000000000000000000000000000001'
          )
        end

        it 'skips blobs with unexpected keys' do
          expect { job.perform }.to_not change { droplet_files.reload }
          expect(droplet_files.reload.size).to eq 1
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to eq(:orphaned_droplets_cleanup)
      end
    end
  end
end
