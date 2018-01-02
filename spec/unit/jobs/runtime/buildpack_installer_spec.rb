require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe BuildpackInstaller, job_context: :worker do
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

          context 'buildpack zip does not specify stack' do
            it 'creates a new buildpack with default stack' do
              expect {
                job.perform
              }.to change { Buildpack.count }.from(0).to(1)

              buildpack = Buildpack.first
              expect(buildpack).to_not be_nil
              expect(buildpack.name).to eq(buildpack_name)
              expect(buildpack.stack).to eq(Stack.default.name)
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

            it 'does nothing if multiple buildpacks with same name' do
              Stack.make(name: 'stack-1')
              Stack.make(name: 'stack-2')
              Buildpack.make(name: buildpack_name, stack: 'stack-1', filename: nil)
              Buildpack.make(name: buildpack_name, stack: 'stack-2', filename: nil)

              update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: false })
              expect {
                update_job.perform
              }.to_not change { Buildpack.count }

              buildpack1 = Buildpack.find(name: buildpack_name, stack: 'stack-1')
              expect(buildpack1).to_not be_nil
              expect(buildpack1.filename).to be_nil

              buildpack2 = Buildpack.find(name: buildpack_name, stack: 'stack-2')
              expect(buildpack2).to_not be_nil
              expect(buildpack2.filename).to be_nil
            end
          end

          context 'buildpack zip specifies stack' do
            before { Stack.make(name: 'manifest-stack') }
            let(:zipfile) do
              path = Tempfile.new('bp-zip-with-stack').path
              TestZip.create(path, 1, 1024) do |zipfile|
                zipfile.get_output_stream('manifest.yml') do |f|
                  f.write("---\nstack: manifest-stack\n")
                end
              end
              path
            end
            after { FileUtils.rm(zipfile) }

            it 'creates a new buildpack with that stack' do
              expect {
                job.perform
              }.to change { Buildpack.count }.from(0).to(1)

              buildpack = Buildpack.first
              expect(buildpack).to_not be_nil
              expect(buildpack.name).to eq(buildpack_name)
              expect(buildpack.stack).to eq('manifest-stack')
              expect(buildpack.key).to start_with(buildpack.guid)
              expect(buildpack.filename).to end_with(File.basename(zipfile))
              expect(buildpack).to be_locked
            end

            it 'updates an existing buildpack' do
              buildpack1 = Buildpack.make(name: buildpack_name, stack: 'manifest-stack', key: 'new_key')

              update_job = BuildpackInstaller.new(buildpack_name, zipfile, { enabled: false })
              update_job.perform

              buildpack2 = Buildpack.find(name: buildpack_name)
              expect(buildpack2).to_not be_nil
              expect(buildpack2.enabled).to be false
              expect(buildpack2.filename).to end_with(File.basename(zipfile))
              expect(buildpack2.key).to_not eql(buildpack1.key)
            end

            it 'updates an existing buildpack with nil stack' do
              buildpack1 = Buildpack.make(name: buildpack_name, stack: nil, key: 'new_key')

              update_job = BuildpackInstaller.new(buildpack_name, zipfile, { enabled: false })
              update_job.perform

              buildpack2 = Buildpack.find(name: buildpack_name)
              expect(buildpack2).to_not be_nil
              expect(buildpack2.enabled).to be false
              expect(buildpack2.filename).to end_with(File.basename(zipfile))
              expect(buildpack2.key).to_not eql(buildpack1.key)
              expect(buildpack2.stack).to eql('manifest-stack')
            end

            it 'creates a new buildpack if existing buildpacks have different stacks' do
              Stack.make(name: 'stack-1')
              Stack.make(name: 'stack-2')
              Buildpack.make(name: buildpack_name, stack: 'stack-1', filename: nil)
              Buildpack.make(name: buildpack_name, stack: 'stack-2', filename: nil)

              update_job = BuildpackInstaller.new(buildpack_name, zipfile, { enabled: false })
              expect {
                update_job.perform
              }.to change { Buildpack.count }.by(1)

              buildpack1 = Buildpack.find(name: buildpack_name, stack: 'stack-1')
              expect(buildpack1).to_not be_nil
              expect(buildpack1.filename).to be_nil

              buildpack2 = Buildpack.find(name: buildpack_name, stack: 'stack-2')
              expect(buildpack2).to_not be_nil
              expect(buildpack2.filename).to be_nil

              buildpack3 = Buildpack.find(name: buildpack_name, stack: 'manifest-stack')
              expect(buildpack3).to_not be_nil
              expect(buildpack3.filename).to_not be_nil
            end
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
