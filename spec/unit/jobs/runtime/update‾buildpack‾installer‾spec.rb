require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe UpdateBuildpackInstaller, job_context: :worker do
      let(:zipfile) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
      let(:zipfile2) { File.expand_path('../../../fixtures/good_relative_paths.zip', File.dirname(__FILE__)) }

      let(:new_buildpack_options) { { enabled: true, locked: true, position: 1 } }
      let(:stack_name) { 'mystack' }
      let(:existing_stack) { Stack.make(name: 'existing-stack') }
      let!(:existing_buildpack) { Buildpack.make(name: 'mybuildpack', stack: nil, filename: nil, enabled: false) }
      let(:job_options) do
        {
          name: 'mybuildpack',
          stack: stack_name,
          file: zipfile,
          options: new_buildpack_options,
          upgrade_buildpack_guid: existing_buildpack.guid
        }
      end
      let(:job) { UpdateBuildpackInstaller.new(job_options) }

      it 'is a valid job' do
        expect(job).to be_a_valid_job
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:buildpack_installer)
      end

      describe '#perform' do
        context 'when a buildpack should be updated' do
          let(:new_buildpack_options) { { locked: true } }

          let(:job_options) do
            {
              name: 'mybuildpack',
              stack: existing_stack.name,
              file: zipfile2,
              options: new_buildpack_options,
              upgrade_buildpack_guid: existing_buildpack.guid
            }
          end

          it 'updates an existing buildpack' do
            buildpack = Buildpack.find(name: 'mybuildpack')
            expect(buildpack.stack).to be_nil
            job.perform

            buildpack.reload
            expect(buildpack).to_not be_nil
            expect(buildpack.enabled).to be false
            expect(buildpack.filename).to end_with(File.basename(zipfile2))
            expect(buildpack.key).to_not eql(existing_buildpack.key)
            expect(buildpack.stack).to eq(existing_stack.name)
          end

          context 'but that buildpack exists and is locked' do
            let(:existing_buildpack) { Buildpack.make(name: 'lockedbuildpack', stack: existing_stack.name, locked: true) }

            it 'does not update a locked buildpack' do
              job.perform

              buildpack2 = Buildpack.find(name: 'lockedbuildpack')
              expect(buildpack2).to eql(existing_buildpack)
            end
          end
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
            expect(logger).to have_received(:error).with(/Buildpack .* failed to update/)
          end
        end

        context 'when uploading the buildpack fails' do
          before do
            allow_any_instance_of(UploadBuildpack).to receive(:upload_buildpack).and_raise
          end

          context 'with an existing buildpack' do
            let(:existing_stack) { Stack.make(name: 'existing-stack') }
            let!(:existing_buildpack) { Buildpack.make(name: 'mybuildpack', stack: existing_stack.name) }

            it 'does not update any values on the buildpack and re-raises the error' do
              expect {
                job.perform
              }.to raise_error(RuntimeError)

              expect(Buildpack.find(name: 'mybuildpack')).to eql(existing_buildpack)
            end
          end
        end
      end
    end
  end
end
