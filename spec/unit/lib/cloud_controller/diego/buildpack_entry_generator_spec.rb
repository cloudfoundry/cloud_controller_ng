require "spec_helper"

module VCAP::CloudController::Diego
  describe BuildpackEntryGenerator do
    subject(:buildpack_entry_generator) { BuildpackEntryGenerator.new(blobstore_url_generator) }
    let(:app) { VCAP::CloudController::AppFactory.make(command: "/a/custom/command") }

    let(:admin_buildpack_download_url) { "http://admin-buildpack.com" }
    let(:app_package_download_url) { "http://app-package.com" }
    let(:build_artifacts_cache_download_uri) { "http://buildpack-artifacts-cache.com" }

    let(:blobstore_url_generator) { double("fake url generator") }

    before do
      VCAP::CloudController::Buildpack.create(name: "java", key: "java-buildpack-guid", position: 1)
      VCAP::CloudController::Buildpack.create(name: "ruby", key: "ruby-buildpack-guid", position: 2)

      allow(blobstore_url_generator).to receive(:app_package_download_url).and_return(app_package_download_url)
      allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return(admin_buildpack_download_url)
      allow(blobstore_url_generator).to receive(:buildpack_cache_download_url).and_return(build_artifacts_cache_download_uri)

      allow(EM).to receive(:add_timer)
      allow(EM).to receive(:defer).and_yield
    end

    describe "#buildpack_entries" do
      context "when the app has a CustomBuildpack" do
        context "when the CustomBuildpack uri begins with http(s)://" do
          before do
            app.buildpack = "http://github.com/mybuildpack/bp.zip"
          end

          it "should use the CustomBuildpack's uri and name it 'custom', and use the url as the key" do
            expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                             { name: "custom", key: "http://github.com/mybuildpack/bp.zip", url: "http://github.com/mybuildpack/bp.zip" }
                                                                           ])
          end
        end

        context "when the CustomBuildpack uri begins with git://" do
          before do
            app.buildpack = "git://github.com/mybuildpack/bp"
          end

          it "should use the list of admin buildpacks" do
            expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                             { name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url },
                                                                             { name: "ruby", key: "ruby-buildpack-guid", url: admin_buildpack_download_url },
                                                                           ])
          end
        end

        context "when the CustomBuildpack uri ends with .git" do
          before do
            app.buildpack = "https://github.com/mybuildpack/bp.git"
          end

          it "should use the list of admin buildpacks" do
            expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                             { name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url },
                                                                             { name: "ruby", key: "ruby-buildpack-guid", url: admin_buildpack_download_url },
                                                                           ])
          end
        end
      end

      context "when the app has a named buildpack" do
        before do
          app.buildpack = "java"
        end

        it "should use that buildpack" do
          expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                           { name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url },
                                                                         ])
        end
      end

      context "when the app has no buildpack specified" do
        it "should use the list of admin buildpacks" do
          expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                                                                           { name: "java", key: "java-buildpack-guid", url: admin_buildpack_download_url },
                                                                           { name: "ruby", key: "ruby-buildpack-guid", url: admin_buildpack_download_url },
                                                                         ])
        end
      end
    end
  end
end
