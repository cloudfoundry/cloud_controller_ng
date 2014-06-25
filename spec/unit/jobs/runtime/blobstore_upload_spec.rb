require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe BlobstoreUpload do
      let(:local_file) { Tempfile.new("tmpfile") }
      let(:blobstore_key) { "key" }
      let(:blobstore_name) { :droplet_blobstore }

      subject(:job) do
        BlobstoreUpload.new(local_file.path, blobstore_key, blobstore_name)
      end

      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
        CloudController::DependencyLocator.instance.stub(:droplet_blobstore).and_return(blobstore)
        blobstore
      end

      it { should be_a_valid_job }

      describe "#perform" do
        it "uploads the file to the blostore" do
          expect {
            job.perform
          }.to change {
            blobstore.exists?(blobstore_key)
          }.to(true)
        end

        it "cleans up the file at the end" do
          job.perform
          expect(File.exists?(local_file.path)).to be false
        end

        it "succeeds if the file is missing" do
          FileUtils.rm_f(local_file)
          expect{ job.perform }.to_not raise_exception
        end
      end

      describe "#error" do
        let(:worker) { Delayed::Worker.new }
        let(:blobstore_upload_job) do
          BlobstoreUpload.class_eval do
            def reschedule_at(_, _= nil)
              #induce the jobs to reschedule almost immediately instead of waiting around for the backoff algorithm
              Time.now
            end
          end
          BlobstoreUpload.new(local_file.path, blobstore_key, blobstore_name)
        end

        before do
          Delayed::Worker.destroy_failed_jobs = false
          allow(blobstore).to receive(:cp_to_blobstore) { raise "UPLOAD FAILED" }
          Delayed::Job.enqueue(blobstore_upload_job, queue: worker.name)
          worker.work_off 1
        end

        context "retrying" do
          it "does not delete the file" do
            worker.work_off 1
            expect(File.exists?(local_file.path)).to be true
          end
        end


        context "when its the final attempt" do
          it "it deletes the file" do
            worker.work_off 1

            expect {
              worker.work_off 1
            }.to change{
              File.exists?(local_file.path)
            }.from(true).to(false)
          end
        end
      end

      it "knows its job name" do
        expect(job.job_name_in_configuration).to equal(:blobstore_upload)
      end
    end
  end
end
