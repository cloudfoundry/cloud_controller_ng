require "spec_helper"

module CloudController
  module Blobstore
    describe UrlGenerator do
      let(:blobstore_host) do
        "api.example.com"
      end

      let(:blobstore_port) do
        9292
      end

      let(:connection_options) do
        {
          blobstore_host: blobstore_host,
          blobstore_port: blobstore_port,
          user: "username",
          password: "password",
        }
      end

      let(:package_blobstore) { double(local?: true) }
      let(:buildpack_cache_blobstore) { double(local?: true) }
      let(:admin_buildpack_blobstore) { double(local?: true) }
      let(:droplet_blobstore) { double(local?: true) }

      subject(:url_generator) do
        UrlGenerator.new(connection_options,
                         package_blobstore,
                         buildpack_cache_blobstore,
                         admin_buildpack_blobstore,
                         droplet_blobstore)
      end

      let(:app) { VCAP::CloudController::AppFactory.make }

      context "downloads" do
        describe "app package" do
          context "when the packages are stored on local blobstore" do
            context "and the package exists" do
              before { package_blobstore.stub(download_uri: "/a/b/c") }

              it "gives a local URI to the blobstore host/port" do
                uri = URI.parse(url_generator.app_package_download_url(app))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql "username"
                expect(uri.password).to eql "password"
                expect(uri.path).to eql "/staging/apps/#{app.guid}"
              end
            end

            context "and the package does not exist" do
              before { package_blobstore.stub(download_uri: nil) }

              it "returns nil" do
                expect(url_generator.app_package_download_url(app)).to be_nil
              end
            end
          end

          context "when the packages are stored remotely" do
            let(:package_blobstore) { double(local?: false) }

            it "gives out signed url to remote blobstore for appbits" do
              remote_uri = "http://s3.example.com/signed"

              package_blobstore.should_receive(:download_uri).with(app.guid).and_return(remote_uri)

              expect(url_generator.app_package_download_url(app)).to eql(remote_uri)
            end
          end

          context "when the droplet doesn't exist (app created before droplet)" do
            it "should return a nil url for stage/start first instance" do
              app.droplets_dataset.destroy
              app.droplet_hash = nil
              app.save
              app.reload
              expect(url_generator.droplet_download_url(app)).to be_nil
            end
          end
        end

        describe "buildpack cache" do
          context "when the caches are stored on local blobstore" do
            context "and the package exists" do
              before { buildpack_cache_blobstore.stub(download_uri: "/a/b/c") }

              it "gives a local URI to the blobstore host/port" do
                uri = URI.parse(url_generator.buildpack_cache_download_url(app))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql "username"
                expect(uri.password).to eql "password"
                expect(uri.path).to eql "/staging/buildpack_cache/#{app.guid}/download"
              end
            end

            context "and the package does not exist" do
              before { buildpack_cache_blobstore.stub(download_uri: nil) }

              it "returns nil" do
                expect(url_generator.buildpack_cache_download_url(app)).to be_nil
              end
            end
          end

          context "when the packages are stored remotely" do
            let(:buildpack_cache_blobstore) { double(local?: false) }

            it "gives out signed url to remote blobstore for appbits" do
              remote_uri = "http://s3.example.com/signed"

              buildpack_cache_blobstore.should_receive(:download_uri).with(app.guid).and_return(remote_uri)

              expect(url_generator.buildpack_cache_download_url(app)).to eql(remote_uri)
            end
          end
        end

        context "admin buildpacks" do
          let(:buildpack) { VCAP::CloudController::Buildpack.make }

          context "when the admin buildpacks are stored on local blobstore" do
            context "and the package exists" do
              before { admin_buildpack_blobstore.stub(download_uri: "/a/b/c") }

              it "gives a local URI to the blobstore host/port" do
                uri = URI.parse(url_generator.admin_buildpack_download_url(buildpack))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql "username"
                expect(uri.password).to eql "password"
                expect(uri.path).to eql "/v2/buildpacks/#{buildpack.guid}/download"
              end
            end

            context "and the package does not exist" do
              before { admin_buildpack_blobstore.stub(download_uri: nil) }

              it "returns nil" do
                expect(url_generator.admin_buildpack_download_url(buildpack)).to be_nil
              end
            end
          end

          context "when the buildpack are stored remotely" do
            let(:admin_buildpack_blobstore) { double(local?: false) }

            it "gives out signed url to remote blobstore for appbits" do
              remote_uri = "http://s3.example.com/signed"
              admin_buildpack_blobstore.should_receive(:download_uri).with(buildpack.key).and_return(remote_uri)
              expect(url_generator.admin_buildpack_download_url(buildpack)).to eql(remote_uri)
            end
          end
        end

        context "droplets" do
          let(:app) { VCAP::CloudController::AppFactory.make }
          let(:blob) { double("blob", download_url: "http://example.com/blob") }

          before do
            CloudController::DependencyLocator.instance.stub(:droplet_blobstore).
              and_return(droplet_blobstore)
          end

          context "when the droplets are stored on local blobstore" do
            context "and the package exists" do
              let(:droplet_blobstore) do
                double(local?: true, blob: blob, exists?: true)
              end

              it "gives a local URI to the blobstore host/port" do
                uri = URI.parse(url_generator.droplet_download_url(app))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql "username"
                expect(uri.password).to eql "password"
                expect(uri.path).to eql "/staging/droplets/#{app.guid}/download"
              end
            end

            context "and the droplet does not exist" do
              let(:droplet_blobstore) do
                double(local?: true, blob: nil, exists?: false)
              end

              it "returns nil" do
                expect(url_generator.droplet_download_url(app)).to be_nil
              end
            end
          end

          context "when the buildpack are stored remotely" do
            let(:droplet_blobstore) do
              double(local?: false, blob: blob, exists?: true)
            end

            it "gives out signed url to remote blobstore from the blob" do
              expect(url_generator.droplet_download_url(app)).to eql("http://example.com/blob")
            end
          end
        end
      end

      context "uploads" do
        it "gives out url for droplets" do
          uri = URI.parse(url_generator.droplet_upload_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql "username"
          expect(uri.password).to eql "password"
          expect(uri.path).to eql "/staging/droplets/#{app.guid}/upload"
        end

        it "gives out url for buidpack cache" do
          uri = URI.parse(url_generator.buildpack_cache_upload_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql "username"
          expect(uri.password).to eql "password"
          expect(uri.path).to eql "/staging/buildpack_cache/#{app.guid}/upload"
        end
      end
    end
  end
end
