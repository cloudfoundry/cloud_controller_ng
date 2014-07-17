require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe BuildpackInstaller do
      let(:buildpack_name) { "mybuildpack" }

      let(:zipfile) { File.expand_path("../../../fixtures/good.zip", File.dirname(__FILE__)) }
      let(:zipfile2) { File.expand_path("../../../fixtures/good_relative_paths.zip", File.dirname(__FILE__)) }

      let(:options) { {} }

      let(:job) { BuildpackInstaller.new(buildpack_name, zipfile, options, TestConfig.config) }

      it { is_expected.to be_a_valid_job }

      describe "#perform" do
        context "default options" do
          it "creates a new buildpack" do
            job.perform

            buildpack = Buildpack.find(name: buildpack_name)
            expect(buildpack).to_not be_nil
            expect(buildpack.name).to eq(buildpack_name)
            expect(buildpack.key).to start_with(buildpack.guid)
            expect(buildpack.filename).to end_with(File.basename(zipfile))
          end

          it "updates an existing buildpack" do
            job.perform
            buildpack1 = Buildpack.find(name: buildpack_name)

            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: false }, TestConfig.config)
            update_job.perform

            buildpack2 = Buildpack.find(name: buildpack_name)
            expect(buildpack2).to_not be_nil
            expect(buildpack2.enabled).to be false
            expect(buildpack2.filename).to end_with(File.basename(zipfile2))
            expect(buildpack2.key).to_not eql(buildpack1.key)
          end

          context "when trying to lock the buildpack" do
            let(:options) { {locked: true} }

            it "locks the buildpack" do
              Buildpack.make(name: buildpack_name)
              job.perform
              buildpack = Buildpack.find(name: buildpack_name)
              expect(buildpack).to be_locked
            end
          end
        end

        context "when locking is enabled" do
          let (:options) { { locked: true } }

          it "creates a locked buildpack" do
            job.perform

            buildpack = Buildpack.find(name: buildpack_name)
            expect(buildpack.locked).to be true
          end

          it "fails to update a locked buildpack" do
            job.perform
            buildpack = Buildpack.find(name: buildpack_name)

            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: false, locked: false }, TestConfig.config)
            update_job.perform

            buildpack2 = Buildpack.find(name: buildpack_name)
            expect(buildpack2).to eql(buildpack)
          end
        end

        context "when disabled" do
          let (:options) { { enabled: false } }

          it "creates a disabled buildpack" do
            job.perform

            buildpack = Buildpack.find(name: buildpack_name)
            expect(buildpack.enabled).to be false
          end

          it "updates a disabled buildpack" do
            job.perform

            buildpack = Buildpack.find(name: buildpack_name)

            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: true }, TestConfig.config)
            update_job.perform

            buildpack2 = Buildpack.find(name: buildpack_name)
            expect(buildpack2.enabled).to be true
          end
        end

        it "knows its job name" do
          expect(job.job_name_in_configuration).to equal(:buildpack_installer)
        end

        context "when the job raises an exception" do
          let(:error) { StandardError.new("same message") }
          let(:logger) { double(:logger) }

          before do
            allow(Steno).to receive(:logger).and_return(logger)
            allow(logger).to receive(:info).and_raise(error) # just a way to trigger an exception when calling #perform
            allow(logger).to receive(:error)
          end

          it "logs the exception and re-raises the exception" do
            expect { job.perform }.to raise_error(error, "same message")
            expect(logger).to have_received(:error).with(/Buildpack .* failed to install or update/)
          end
        end
      end
    end
  end
end
