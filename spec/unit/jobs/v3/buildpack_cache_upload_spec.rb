require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe BuildpackCacheUpload, job_context: :api do
      subject(:job) { BuildpackCacheUpload.new(local_path: local_file.path, app_guid: app.guid, stack_name: 'some-stack') }

      let(:app) { AppModel.make(:buildpack) }

      let(:file_content) { 'some_file_content' }
      let(:local_file) do
        Tempfile.new('local_file').tap do |f|
          f.write(file_content)
          f.chmod(400)
          f.flush
        end
      end

      let!(:blobstore) do
        blobstore = CloudController::DependencyLocator.instance.buildpack_cache_blobstore
        allow(CloudController::DependencyLocator.instance).to receive(:buildpack_cache_blobstore).and_return(blobstore)
        blobstore
      end
      let!(:blobstore_key) { Presenters::V3::CacheKeyPresenter.cache_key(guid: app.guid, stack_name: 'some-stack') }

      before do
        app.lifecycle_data.update(stack: 'some-stack')
        app.reload
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'uploads the buildpack cache to the blobstore' do
          job.perform

          downloaded_file = Tempfile.new('downloaded_file')
          blobstore.download_from_blobstore(blobstore_key, downloaded_file.path)
          expect(downloaded_file.read).to eql(file_content)
        end

        it 'updates the buildpack cache checksum' do
          sha256_digest = Digester.new(algorithm: OpenSSL::Digest::SHA256).digest_file(local_file)

          expect { job.perform }.to change { app.refresh.buildpack_cache_sha256_checksum }.to(sha256_digest)
        end

        it 'deletes the uploaded file' do
          job.perform
          expect(File).not_to exist(local_file.path)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_cache_upload)
        end

        context 'when the blobstore is local' do
          before do
            allow(blobstore).to receive(:local?).and_return(true)
            allow(FileUtils).to receive(:chmod).and_call_original
          end

          it 'makes the file writable before copying it' do
            job.perform

            expect(FileUtils).to have_received(:chmod).with('u=wr', local_file.path)
          end
        end

        context 'when the blobstore is not local' do
          before do
            allow(blobstore).to receive(:local?).and_return(false)
            allow(FileUtils).to receive(:chmod).and_call_original
          end

          it 'does not change the permissions of the file' do
            job.perform

            expect(FileUtils).not_to have_received(:chmod)
          end
        end

        context 'when the app record no longer exists' do
          before { app.destroy }

          it 'does not try to upload the droplet' do
            job.perform

            downloaded_file = Tempfile.new('downloaded_file')
            blobstore.download_from_blobstore(blobstore_key, downloaded_file.path)
            expect(downloaded_file.read).to eql('')
          end

          it 'deletes the local file' do
            job.perform
            expect(File).not_to exist(local_file.path)
          end
        end

        context 'when upload is a failure' do
          subject(:job) do
            BuildpackCacheUpload.class_eval do
              def reschedule_at(_, _=nil)
                # induce the jobs to reschedule almost immediately instead of waiting around for the backoff algorithm
                Time.now.utc
              end
            end
            BuildpackCacheUpload.new(local_path: local_file.path, app_guid: app.guid, stack_name: 'some-stack')
          end

          let(:worker) { Delayed::Worker.new }

          before do
            Delayed::Worker.destroy_failed_jobs = false
            Delayed::Job.enqueue(job, queue: worker.name)
          end

          context 'copying to the blobstore fails' do
            before do
              allow(blobstore).to receive(:cp_to_blobstore).and_raise(RuntimeError, 'Something Terrible Happened')
              worker.work_off 1
            end

            it 'does not record the buildpack cache checksums' do
              expect(app.refresh.buildpack_cache_sha256_checksum).to be_nil
            end

            it 'records the failure' do
              expect(Delayed::Job.last.last_error).to match(/Something Terrible Happened/)
            end

            context 'retrying' do
              it 'does not delete the file' do
                expect(File).to exist(local_file.path)
              end
            end

            context 'when its the final attempt' do
              it 'deletes the file' do
                worker.work_off 1

                expect do
                  worker.work_off 1
                end.to change {
                  File.exist?(local_file.path)
                }.from(true).to(false)
              end
            end
          end

          context 'if the file is missing' do
            before do
              FileUtils.rm_f(local_file)
              worker.work_off 1
            end

            it 'receives an error' do
              expect(Delayed::Job.last.last_error).to match(/No such file or directory/)
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
