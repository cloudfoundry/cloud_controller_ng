require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe BuildpackInstaller do
      let(:buildpack_name) { 'mybuildpack' }

      let(:zipfile) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
      let(:zipfile2) { File.expand_path('../../../fixtures/good_relative_paths.zip', File.dirname(__FILE__)) }

      let(:options) { { enabled: true, locked: false, position: 1 } }

      let(:job) { BuildpackInstaller.new(buildpack_name, zipfile, options) }

      it 'is a valid job' do
        expect(job).to be_a_valid_job
      end

      describe '#perform' do
        context 'when the buildpack is enabled and unlocked' do
          let(:options) { { locked: true } }

          it 'creates a new buildpack' do
            expect {
              job.perform
            }.to change { Buildpack.count }.from(0).to(1)

            buildpack = Buildpack.find(name: buildpack_name)
            expect(buildpack).to_not be_nil
            expect(buildpack.name).to eq(buildpack_name)
            expect(buildpack.key).to start_with(buildpack.guid)
            expect(buildpack.filename).to end_with(File.basename(zipfile))
            expect(buildpack).to be_locked
          end

          it 'updates an existing buildpack' do
            buildpack1 = Buildpack.make(name: buildpack_name, key: 'new_key')

            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: false })
            update_job.perform

            buildpack2 = Buildpack.find(name: buildpack_name)
            expect(buildpack2).to_not be_nil
            expect(buildpack2.enabled).to be false
            expect(buildpack2.filename).to end_with(File.basename(zipfile2))
            expect(buildpack2.key).to_not eql(buildpack1.key)
          end
        end

        context 'when the buildpack is locked' do
          it 'fails to update a locked buildpack' do
            buildpack = Buildpack.make(name: buildpack_name, locked: true)
            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: false, locked: false })
            update_job.perform

            buildpack2 = Buildpack.find(name: buildpack_name)
            expect(buildpack2).to eql(buildpack)
          end
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_installer)
        end

        context 'when the job raises an exception' do
          let(:error) { StandardError.new('same message') }
          let(:logger) { double(:logger) }

          before do
            allow(Steno).to receive(:logger).and_return(logger)
            allow(logger).to receive(:info).and_raise(error) # just a way to trigger an exception when calling #perform
            allow(logger).to receive(:error)
          end

          it 'logs the exception and re-raises the exception' do
            expect { job.perform }.to raise_error(error, 'same message')
            expect(logger).to have_received(:error).with(/Buildpack .* failed to install or update/)
          end
        end

        context 'when uploading the buildpack fails' do
          before do
            allow_any_instance_of(UploadBuildpack).to receive(:upload_buildpack).and_raise
          end

          context 'with a new buildpack' do
            it 'does not create a buildpack and re-raises the error' do
              expect {
                expect {
                  job.perform
                }.to raise_error(RuntimeError)
              }.to_not change { Buildpack.count }
            end
          end

          context 'with an existing buildpack' do
            let!(:buildpack) { Buildpack.make(name: buildpack_name, enabled: false) }

            it 'does not update any values on the buildpack and re-raises the error' do
              expect {
                job.perform
              }.to raise_error(RuntimeError)

              expect(Buildpack.find(name: buildpack_name)).to eql(buildpack)
            end
          end
        end
      end
    end
  end
end
