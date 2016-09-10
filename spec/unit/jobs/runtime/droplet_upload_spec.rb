require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe DropletUpload do
      let(:app) { App.make }
      let(:file_content) { 'some_file_content' }
      let(:message_bus) { CfMessageBus::MockMessageBus.new }

      let(:local_file) do
        f = Tempfile.new('tmpfile')
        f.write(file_content)
        f.flush
        f
      end

      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
        allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(blobstore)
        blobstore
      end

      subject(:job) { DropletUpload.new(local_file.path, app.id) }

      it { is_expected.to be_a_valid_job }

      it "updates the app's droplet hash" do
        expect {
          job.perform
        }.to change {
          app.refresh.droplet_hash
        }
      end

      it 'makes the app have a downloadable droplet' do
        job.perform
        app.reload

        expect(app.current_droplet).to be

        downloaded_file = Tempfile.new('')
        app.current_droplet.download_to(downloaded_file.path)
        expect(downloaded_file.read).to eql(file_content)
      end

      it 'stores the droplet in the blobstore' do
        expect {
          job.perform
        }.to change {
          CloudController::DropletUploader.new(app.refresh, blobstore)
          app.droplets.size
        }.from(0).to(1)
      end

      it 'expires old droplets' do
        config = {
          droplets: {
            max_staged_droplets_stored: 5
          }
        }
        expect {
          10.times do
            Tempfile.open('tmpfile') do |f|
              f.write(file_content)
              f.close
              DropletUpload.new(f.path, app.id, config).perform
            end
          end
        }.to change {
          CloudController::DropletUploader.new(app.refresh, blobstore)
          app.droplets.size
        }.from(0).to(config[:droplets][:max_staged_droplets_stored])
      end

      it 'deletes the uploaded file' do
        expect(FileUtils).to receive(:rm_f).with(local_file.path)
        job.perform
      end

      context 'when the app no longer exists' do
        subject(:job) { DropletUpload.new(local_file.path, 99999999) }

        it 'should not try to upload the droplet' do
          uploader = double(:uploader)
          expect(uploader).not_to receive(:upload)
          allow(CloudController::DropletUploader).to receive(:new) { uploader }
          job.perform
        end
      end

      context 'when upload is a failure' do
        let(:worker) { Delayed::Worker.new }
        let(:droplet_upload_job) do
          DropletUpload.class_eval do
            def reschedule_at(_, _=nil)
              # induce the jobs to reschedule almost immediately instead of waiting around for the backoff algorithm
              Time.now.utc
            end
          end
          DropletUpload.new(local_file.path, app.id)
        end

        before do
          Delayed::Worker.destroy_failed_jobs = false
          Delayed::Job.enqueue(droplet_upload_job, queue: worker.name)
        end

        context 'copying to the blobstore fails' do
          before do
            allow(CloudController::DropletUploader).to receive(:new).and_raise(RuntimeError, 'Something Terrible Happened')
            worker.work_off 1
          end

          it 'records the failure' do
            expect(Delayed::Job.last.last_error).to match /Something Terrible Happened/
          end

          context 'not retrying' do
            it 'does delete the file' do
              expect(File.exist?(local_file.path)).to be false
            end
          end
        end

        context 'if the file is missing' do
          before do
            FileUtils.rm_f(local_file)
            allow(CloudController::DropletUploader).to receive(:new).and_raise(RuntimeError, 'File not found')
            worker.work_off 1
          end

          it 'receives an error' do
            expect(Delayed::Job.last.last_error).to match /File not found/
          end

          it 'does not retry' do
            worker.work_off 1
            expect(Delayed::Job.last.attempts).to eq 1
          end
        end
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:droplet_upload)
      end
    end
  end
end
