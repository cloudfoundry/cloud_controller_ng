require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe CreateBuildpackInstaller, job_context: :worker do
      let(:zipfile) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
      let(:zipfile2) { File.expand_path('../../../fixtures/good_relative_paths.zip', File.dirname(__FILE__)) }

      let(:new_buildpack_options) { { enabled: true, locked: true, position: 1 } }
      let(:stack_name) { 'mystack' }
      let(:job_options) { { name: 'mybuildpack', stack: stack_name, file: zipfile, options: new_buildpack_options } }
      let(:job) { CreateBuildpackInstaller.new(job_options) }

      it 'is a valid job' do
        expect(job).to be_a_valid_job
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:buildpack_installer)
      end

      describe '#perform' do
        context 'when creating a buildpack' do
          shared_examples_for :creating_a_buildpack do
            it 'creates a new buildpack with the requested stack' do
              expect {
                job.perform
              }.to change { Buildpack.count }.from(0).to(1)

              buildpack = Buildpack.first
              expect(buildpack).to_not be_nil
              expect(buildpack.name).to eq('mybuildpack')
              expect(buildpack.stack).to eq(stack_name)
              expect(buildpack.key).to start_with(buildpack.guid)
              expect(buildpack.filename).to end_with(File.basename(zipfile))
              expect(buildpack).to be_locked
            end
          end

          context 'when the no stack is requested' do
            let(:stack_name) { nil }
            it_behaves_like :creating_a_buildpack
          end

          context 'when the requested stack does not exist' do
            let(:stack_name) { 'mystack' }

            it 'raises an error' do
              expect {
                job.perform
              }.to raise_error(Sequel::ValidationFailed)
            end
          end

          context 'when the requested stack does exist' do
            let!(:existing_stack) { Stack.make(name: stack_name) }

            it_behaves_like :creating_a_buildpack
          end
        end

        context 'when the job raises an exception' do
          let!(:existing_stack) { Stack.make(name: stack_name) }

          let(:error) { StandardError.new('same message') }
          let(:logger) { double(:logger) }

          before do
            allow(Steno).to receive(:logger).and_return(logger)
            allow(logger).to receive(:info).and_raise(error) # just a way to trigger an exception when calling #perform
            allow(logger).to receive(:error)
          end

          it 'logs the exception and re-raises the exception' do
            expect { job.perform }.to raise_error(error, 'same message')
            expect(logger).to have_received(:error).with(/Buildpack .* failed to install/)
          end
        end

        context 'when uploading the buildpack fails' do
          let!(:existing_stack) { Stack.make(name: stack_name) }

          before do
            allow_any_instance_of(UploadBuildpack).to receive(:upload_buildpack).and_raise
          end

          it 'does not create a buildpack and re-raises the error' do
            expect {
              expect {
                job.perform
              }.to raise_error(RuntimeError)
            }.to_not change { Buildpack.count }
          end

          it 'does not create a new stack and re-raises the error' do
            expect {
              expect {
                job.perform
              }.to raise_error(RuntimeError)
            }.to_not change { Stack.count }
          end
        end
      end
    end
  end
end
