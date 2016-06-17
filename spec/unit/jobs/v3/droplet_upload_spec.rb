require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe DropletUpload do
      let(:droplet) { DropletModel.make }
      let(:file_content) { 'some_file_content' }
      let(:local_file) do
        Tempfile.new('local_file').tap do |f|
          f.write(file_content)
          f.flush
        end
      end
      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
        allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(blobstore)
        blobstore
      end

      subject(:job) { DropletUpload.new(local_file.path, droplet.guid) }

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'updates the droplet hash' do
          digest = Digester.new.digest_file(local_file)
          job.perform
          expect(droplet.refresh.droplet_hash).to eq(digest)
        end

        it 'uploads the droplet to the blobstore' do
          job.perform
          droplet.refresh

          downloaded_file = Tempfile.new('downloaded_file')
          blobstore.download_from_blobstore(File.join(droplet.guid, droplet.droplet_hash), downloaded_file.path)
          expect(downloaded_file.read).to eql(file_content)
        end

        it 'deletes the uploaded file' do
          job.perform
          expect(File.exist?(local_file.path)).to be_falsey
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:droplet_upload)
        end

        context 'when the droplet record no longer exists' do
          subject(:job) { DropletUpload.new(local_file.path, 'bad-guid') }

          it 'should not try to upload the droplet' do
            digest = Digester.new.digest_file(local_file)
            job.perform

            downloaded_file = Tempfile.new('downloaded_file')
            blobstore.download_from_blobstore(File.join('bad-guid', digest), downloaded_file.path)
            expect(downloaded_file.read).to eql('')
          end

          it 'deletes the local file' do
            job.perform
            expect(File.exist?(local_file.path)).to be_falsey
          end
        end

        context 'when upload is a failure' do
          let(:worker) { Delayed::Worker.new }
          let(:job) do
            DropletUpload.class_eval do
              def reschedule_at(_, _=nil)
                # induce the jobs to reschedule almost immediately instead of waiting around for the backoff algorithm
                Time.now.utc
              end
            end
            DropletUpload.new(local_file.path, droplet.guid)
          end

          before do
            Delayed::Worker.destroy_failed_jobs = false
            Delayed::Job.enqueue(job, queue: worker.name)
          end

          context 'copying to the blobstore fails' do
            before do
              allow(blobstore).to receive(:cp_to_blobstore).and_raise(RuntimeError, 'Something Terrible Happened')
              worker.work_off 1
            end

            it 'does not record the droplet hash' do
              expect(droplet.refresh.droplet_hash).to be_nil
            end

            it 'records the failure' do
              expect(Delayed::Job.last.last_error).to match /Something Terrible Happened/
            end

            context 'retrying' do
              it 'does not delete the file' do
                expect(File.exist?(local_file.path)).to be_truthy
              end
            end

            context 'when its the final attempt' do
              it 'it deletes the file' do
                worker.work_off 1

                expect {
                  worker.work_off 1
                }.to change {
                  File.exist?(local_file.path)
                }.from(true).to(false)
              end
            end
          end

          context 'if the file is missing' do
            before do
              FileUtils.rm_f(local_file)
              # allow(CloudController::DropletUploader).to receive(:new).and_raise(RuntimeError, 'File not found')
              worker.work_off 1
            end

            it 'receives an error' do
              expect(Delayed::Job.last.last_error).to match /No such file or directory/
            end

            it 'does not retry' do
              worker.work_off 1
              expect(Delayed::Job.last.attempts).to eq 1
            end
          end
        end
      end
    end
  end
end
