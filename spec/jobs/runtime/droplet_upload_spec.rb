require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe DropletUpload do
      let(:app) { App.make }
      let(:file_content) { "some_file_content" }
      let(:message_bus) { CfMessageBus::MockMessageBus.new }

      let(:local_file) do
        f = Tempfile.new("tmpfile")
        f.write(file_content)
        f.flush
        f
      end

      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
        CloudController::DependencyLocator.instance.stub(:droplet_blobstore).and_return(blobstore)
        blobstore
      end

      subject(:job) { DropletUpload.new(local_file.path, app.id) }

      it "updates the app's droplet hash" do
        expect {
          job.perform
        }.to change {
          app.refresh.droplet_hash
        }
      end

      it "marks the app as staged" do
        expect {
          job.perform
        }.to change {
          app.refresh.staged?
        }.from(false).to(true)
      end

      it "makes the app have a downloadable droplet" do
        job.perform
        app.reload

        expect(app.current_droplet).to be

        downloaded_file = Tempfile.new("")
        app.current_droplet.download_to(downloaded_file.path)
        expect(downloaded_file.read).to eql(file_content)
      end

      it "stores the droplet in the blobstore" do
        expect {
          job.perform
        }.to change {
          CloudController::DropletUploader.new(app.refresh, blobstore)
          app.droplets.size
        }.from(0).to(1)
      end

      it "deletes the uploaded file" do
        FileUtils.should_receive(:rm_f).with(local_file.path)
        job.perform
      end

      context "when the app no longer exists" do
        subject(:job) { DropletUpload.new(local_file.path, 99999999) }

        it "should not try to upload the droplet" do
          uploader = double(:uploader)
          expect(uploader).not_to receive(:upload)
          allow(CloudController::DropletUploader).to receive(:new) { uploader }
          job.perform
        end
      end

      context "when upload is a failure" do
        let(:worker) { Delayed::Worker.new }
        let(:droplet_upload_job) do
          DropletUpload.class_eval do
            def reschedule_at(_, _= nil)
              #induce the jobs to reschedule almost immediately instead of waiting around for the backoff algorithm
              Time.now
            end
          end
          DropletUpload.new(local_file.path, app.id)
        end

        before do
          Delayed::Worker.destroy_failed_jobs = false
          allow(CloudController::DropletUploader).to receive(:new).and_raise(RuntimeError, "Something Terrible Happened")
        end

        subject(:run_job_all_3_times) do
          Delayed::Job.enqueue(droplet_upload_job, queue: worker.name)
          3.times do
            worker.work_off
            sleep 0.2
          end
        end

        context "and it retries and the retries also fail" do
          it "we see the correct number of retries and it deletes the file" do
            expect(FileUtils).to receive(:rm_f).with(local_file.path)

            expect {
              run_job_all_3_times
            }.to change {
              Delayed::Job.count
            }.by(1)

            expect(Delayed::Job.last.attempts).to eq 3
            expect(Delayed::Job.last.last_error).to match /Something Terrible Happened/
          end
        end
      end

      it "knows its job name" do
        expect(job.job_name_in_configuration).to equal(:droplet_upload)
      end
    end
  end
end
