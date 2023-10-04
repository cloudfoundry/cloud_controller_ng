require 'spec_helper'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe DropletUpload, job_context: :api do
      let(:droplet) { DropletModel.make(state: 'STAGING', droplet_hash: nil, sha256_checksum: nil) }
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
      let(:skip_state_transition) { false }

      subject(:job) do
        DropletUpload.new(local_file.path, droplet.guid, skip_state_transition:)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'updates the droplet checksums' do
          sha1_digest = Digester.new.digest_file(local_file)
          sha256_digest = Digester.new(algorithm: OpenSSL::Digest::SHA256).digest_file(local_file)

          job.perform
          expect(droplet.refresh.droplet_hash).to eq(sha1_digest)
          expect(droplet.refresh.sha256_checksum).to eq(sha256_digest)
        end

        context 'when skip_stage_transition is set' do
          let(:skip_state_transition) { true }

          it 'does not mark the droplet as staged' do
            expect { job.perform }.not_to(change { droplet.refresh.state })
          end
        end

        context 'when skip_stage_transition is not set' do
          let(:skip_state_transition) { false }

          it 'marks the droplet as staged' do
            job.perform
            expect(droplet.refresh.state).to eq(DropletModel::STAGED_STATE)
          end
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
          expect(File).not_to exist(local_file.path)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:droplet_upload)
        end

        context 'when the droplet record no longer exists' do
          subject(:job) do
            DropletUpload.new(local_file.path, 'bad-guid', skip_state_transition:)
          end

          it 'does not try to upload the droplet' do
            digest = Digester.new.digest_file(local_file)
            job.perform

            downloaded_file = Tempfile.new('downloaded_file')
            blobstore.download_from_blobstore(File.join('bad-guid', digest), downloaded_file.path)
            expect(downloaded_file.read).to eql('')
          end

          it 'deletes the local file' do
            job.perform
            expect(File).not_to exist(local_file.path)
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
            DropletUpload.new(local_file.path, droplet.guid, skip_state_transition:)
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

            it 'does not record the droplet checksums' do
              expect(droplet.refresh.droplet_hash).to be_nil
              expect(droplet.refresh.sha256_checksum).to be_nil
            end

            it 'marks the droplet state as FAILED' do
              expect(droplet.refresh.state).to eq(DropletModel::FAILED_STATE)
            end

            it 'sets an error description on the droplet model' do
              expect(droplet.refresh.error_description).to eq('Something Terrible Happened')
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
