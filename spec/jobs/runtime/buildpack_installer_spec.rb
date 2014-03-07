require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe BuildpackInstaller do
      let(:buildpack_name) { "mybuildpack" }

      let(:zipfile) { File.expand_path("../../../fixtures/good.zip", __FILE__) }
      let(:zipfile2) { File.expand_path("../../../fixtures/good_relative_paths.zip", __FILE__) }

      let(:options) { {} }

      let(:job) { BuildpackInstaller.new(buildpack_name, zipfile, options, config) }

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

            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: false }, config)
            update_job.perform

            buildpack2 = Buildpack.find(name: buildpack_name)
            expect(buildpack2).to_not be_nil
            expect(buildpack2.enabled).to be_false
            expect(buildpack2.filename).to end_with(File.basename(zipfile2))
            expect(buildpack2.key).to_not eql(buildpack1.key)
          end
        end

        context "when locking is enabled" do
          let (:options) { { locked: true } }

          it "creates a locked buildpack" do
            job.perform

            buildpack = Buildpack.find(name: buildpack_name)
            expect(buildpack.locked).to be_true
          end

          it "fails to update a locked buildpack" do
            job.perform
            buildpack = Buildpack.find(name: buildpack_name)

            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: false, locked: false }, config)
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
            expect(buildpack.enabled).to be_false
          end

          it "updates a disabled buildpack" do
            job.perform

            buildpack = Buildpack.find(name: buildpack_name)

            update_job = BuildpackInstaller.new(buildpack_name, zipfile2, { enabled: true }, config)
            update_job.perform

            buildpack2 = Buildpack.find(name: buildpack_name)
            expect(buildpack2.enabled).to be_true
          end
        end

        it "knows its job name" do
          expect(job.job_name_in_configuration).to equal(:buildpack_installer)
        end
      end
    end
  end
end
