require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::StagingsController, type: :controller do
    let(:max_staging_runtime) { 120 }
    let(:cc_addr) { "1.2.3.4" }
    let(:cc_port) { 5678 }
    let(:staging_user) { "user" }
    let(:staging_password) { "password" }
    let(:app_obj) { App.make :droplet_hash => "some-droplet-hash" }
    let(:workspace) { Dir.mktmpdir }
    let(:original_staging_config) do
      {
        :max_staging_runtime => max_staging_runtime,
        :bind_address => cc_addr,
        :port => cc_port,
        :staging => {
          :auth => {
            :user => staging_user,
            :password => staging_password
          }
        },
        :resource_pool => {
          :fog_connection => {
            :provider => "Local",
            :local_root => Dir.mktmpdir("resourse_pool", workspace)
          }
        },
        :packages => {
          :fog_connection => {
            :provider => "Local",
            :local_root => Dir.mktmpdir("packages", workspace)
          }
        },
        :droplets => {
          :droplet_directory_key => "cc-droplets",
          :fog_connection => {
            :provider => "Local",
            :local_root => Dir.mktmpdir("droplets", workspace)
          }
        },
        :directories => {
          :tmpdir => Dir.mktmpdir("tmpdir", workspace)
        }
      }
    end
    let(:staging_config) { original_staging_config }

    before do
      Fog.unmock!
      config_override(staging_config)
    end

    after { FileUtils.rm_rf(workspace) }

    describe "#create_handle" do
      let(:handle_id) { Sham.guid }

      context "when handle does not exist for given id" do
        it "creates handle with id and empty upload path" do
          StagingsController.create_handle(handle_id).tap do |h|
            h.guid.should == handle_id
            h.upload_path.should be_nil
            h.buildpack_cache_upload_path.should be_nil
          end
        end

        it "remembers handle" do
          expect {
            StagingsController.create_handle(handle_id)
          }.to change { StagingsController.lookup_handle(handle_id) }.from(nil)
        end
      end
    end

    describe "#destroy_handle" do
      let(:handle_id) { Sham.guid }
      let!(:handle) { StagingsController.create_handle(handle_id) }

      context "when the handle exists" do
        def self.it_destroys_handle
          it "destroys the handle" do
            expect {
              StagingsController.destroy_handle(handle)
            }.to change { StagingsController.lookup_handle(handle_id) }.from(handle).to(nil)
          end
        end

        context "when upload_path is set" do
          let(:tmp_file) { Tempfile.new("temp_file") }
          before { handle.upload_path = tmp_file.path }

          context "and the upload path exists" do
            it_destroys_handle

            it "destroys the uploaded file" do
              expect {
                StagingsController.destroy_handle(handle)
              }.to change { File.exists?(tmp_file.path) }.from(true).to(false)
            end
          end

          context "and the upload path does not exist" do
            it_destroys_handle
          end
        end

        context "when upload_path is not set" do
          it_destroys_handle
        end

        context "when buildpack cache upload_path is set" do
          let(:tmp_file) { Tempfile.new("temp_file") }
          before { handle.buildpack_cache_upload_path = tmp_file.path }

          context "and the buildpack cache upload path exists" do
            it_destroys_handle

            it "destroys the buildpack cache uploaded file" do
              expect {
                StagingsController.destroy_handle(handle)
              }.to change { File.exists?(tmp_file.path) }.from(true).to(false)
            end
          end

          context "and the buildpack cache upload path does not exist" do
            it_destroys_handle
          end
        end
      end

      context " when the handle does not exist" do
        it "does nothing" do
          StagingsController.destroy_handle(handle)
        end
      end
    end

    describe "app_uri" do
      it "should return a uri to our cc" do
        uri = StagingsController.app_uri(app_obj)
        uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/apps/#{app_obj.guid}"
      end
    end

    describe "droplet_upload_uri" do
      it "should return a uri to our cc" do
        uri = StagingsController.droplet_upload_uri(app_obj)
        uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/droplets/#{app_obj.guid}/upload"
      end
    end

    describe "droplet_download_uri" do
      it "returns internal cc uri" do
        uri = StagingsController.droplet_download_uri(app_obj)
        uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/droplets/#{app_obj.guid}/download"
      end

      context "when Fog is configured for AWS" do
        let(:staging_config) do
          original_staging_config.tap do |config|
            config[:droplets] = {:fog_connection => {
                :provider => "AWS",
            }}
          end
        end

        before do
          file = double(:file, {
              :url => "https://some-bucket.example.com/ab/cd/abcdefg",
              :key => "123-456",
          })
          StagingsController.blobstore.stub(:files).and_return(double(:files, :head => file))
        end

        it "returns an AWS url" do
          uri = StagingsController.droplet_download_uri(app_obj)
          uri.should == "https://some-bucket.example.com/ab/cd/abcdefg"
        end

        context "with a CDN" do
          let(:staging_config) do
            original_staging_config.tap do |config|
              config[:droplets] = {
                :fog_connection => {
                    :provider => "AWS",
                },
                :cdn => {
                    :uri => "https://cdn.example.com/some-bucket/ab/cd/abcdefg"
                },
              }
            end
          end

          it "returns a URL with the CDN and the file's key" do
            uri = StagingsController.droplet_download_uri(app_obj)
            uri.should == "https://cdn.example.com/some-bucket/ab/cd/abcdefg/123-456"
          end

          context "when CloudFront Signer is configured" do
            before do
              ::AWS::CF::Signer.stub(:is_configured?).and_return(true)
            end

            it "returns a signed URI using the CDN" do
              ::AWS::CF::Signer.should_receive(:sign_url).with("https://cdn.example.com/some-bucket/ab/cd/abcdefg/123-456").and_return("signed_url")
              StagingsController.droplet_uri(app_obj).should == "signed_url"
            end
          end
        end
      end
    end

    describe "buildpack_cache_upload_uri" do
      it "should return a uri to our cc" do
        uri = StagingsController.buildpack_cache_upload_uri(app_obj)
        uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/buildpack_cache/#{app_obj.guid}/upload"
      end
    end

    describe "buildpack_cache_download_uri" do
      let(:buildpack_cache) { Tempfile.new(app_obj.guid) }
      before { StagingsController.store_buildpack_cache(app_obj, buildpack_cache.path) }
      after { FileUtils.rm(buildpack_cache.path) }

      it "returns internal cc uri" do
        uri = StagingsController.buildpack_cache_download_uri(app_obj)
        uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/buildpack_cache/#{app_obj.guid}/download"
      end
    end

    describe ".store_droplet" do
      let(:droplet_upload_path) { Tempfile.new("temp_file") }

      it "copies the application droplet to the blob store" do
        StagingsController.store_droplet(app_obj, droplet_upload_path.path)

        key = File.join(app_obj.guid, app_obj.droplet_hash)
        expect(StagingsController.blobstore.exists?(key)).to be_true
      end
    end

    shared_examples "staging bad auth" do |verb, path|
      it "should return 403 for bad credentials" do
        authorize "hacker", "sw0rdf1sh"
        send(verb, "/staging/#{path}/#{app_obj.guid}")
        last_response.status.should == 403
      end
    end

    describe "GET /staging/apps/:guid" do
      let(:app_obj_without_pkg) { App.make }
      let(:app_package_path) { AppPackage.package_path(app_obj.guid) }

      def self.it_downloads_staged_app
        it "succeeds for valid packages" do
          guid = app_obj.guid
          tmpdir = Dir.mktmpdir
          zipname = File.join(tmpdir, "test.zip")
          create_zip(zipname, 10, 1024)
          AppPackage.to_zip(guid, [], File.new(zipname))
          FileUtils.rm_rf(tmpdir)

          get "/staging/apps/#{app_obj.guid}"
          last_response.status.should == 200
        end

        it "should return an error for non-existent apps" do
          get "/staging/apps/#{Sham.guid}"
          last_response.status.should == 404
        end

        it "should return an error for an app without a package" do
          get "/staging/apps/#{app_obj_without_pkg.guid}"
          last_response.status.should == 404
        end
      end

      context "when using with nginx" do
        before do
          config_override(staging_config)
          authorize(staging_user, staging_password)
        end

        it_downloads_staged_app
        include_examples "staging bad auth", :get, "apps"
      end

      context "when not using with nginx" do
        before do
          config_override(staging_config.merge(:nginx => {:use_nginx => false}))
          authorize(staging_user, staging_password)
        end

        it_downloads_staged_app
        include_examples "staging bad auth", :get, "apps"
      end
    end

    describe "POST /staging/droplets/:guid/upload" do
      let(:tmpfile) { Tempfile.new("droplet.tgz") }
      let(:upload_req) do
        { :upload => { :droplet => Rack::Test::UploadedFile.new(tmpfile) } }
      end

      before do
        config_override(staging_config)
        authorize staging_user, staging_password
      end

      def make_request(droplet_guid=app_obj.guid)
        post "/staging/droplets/#{droplet_guid}/upload", upload_req
      end

      context "with a valid upload handle" do
        let!(:handle) { StagingsController.create_handle(app_obj.guid) }

        after { StagingsController.destroy_handle(handle) }

        context "with valid app" do
          it "returns 200" do
            make_request
            last_response.status.should == 200
          end

          it "stores file path in handle.upload_path" do
            make_request
            File.exists?(handle.upload_path).should be_true
          end
        end

        context "with an invalid app" do
          it "returns 404" do
            make_request("bad")
            last_response.status.should == 404
          end
        end
      end

      context "with an invalid upload handle" do
        it "return 400" do
          make_request
          last_response.status.should == 400
        end
      end

      include_examples "staging bad auth", :post, "droplets"
    end

    describe "GET /staging/droplets/:guid/download" do
      before do
        config_override(staging_config)
        authorize staging_user, staging_password
      end

      context "with a valid droplet" do
        context "with nginx" do
          before { config[:nginx][:use_nginx] = true }

          it "redirects nginx to serve staged droplet" do
            droplet = Tempfile.new(app_obj.guid)
            droplet.write("droplet contents")
            droplet.close
            StagingsController.store_droplet(app_obj, droplet.path)
            StagingsController.blobstore.exists?([app_obj.guid, app_obj.droplet_hash].join("/")).should be_true

            get "/staging/droplets/#{app_obj.guid}/download"
            last_response.status.should == 200
            last_response.headers["X-Accel-Redirect"].should match("/cc-droplets/.*/#{app_obj.guid}")
          end
        end

        context "without nginx" do
          before { config[:nginx][:use_nginx] = false }

          it "should return the droplet" do
            Tempfile.new(app_obj.guid) do |f|
              f.write("droplet contents")
              f.close
              StagingsController.store_droplet(app_obj, f.path)

              get "/staging/droplets/#{app_obj.guid}/download"
              last_response.status.should == 200
              last_response.body.should == "droplet contents"
            end
          end
        end
      end

      context "with a valid app but no droplet" do
        it "should return an error" do
          get "/staging/droplets/#{app_obj.guid}/download"
          last_response.status.should == 400
        end
      end

      context "with an invalid app" do
        it "should return an error" do
          get "/staging/droplets/bad/download"
          last_response.status.should == 404
        end
      end
    end

    describe "POST /staging/buildpack_cache/:guid/upload" do
      let(:tmpfile) { Tempfile.new("droplet.tgz") }
      let(:upload_req) do
        { :upload => { :droplet => Rack::Test::UploadedFile.new(tmpfile) } }
      end

      before do
        config_override(staging_config)
        authorize staging_user, staging_password
      end

      def make_request(droplet_guid=app_obj.guid)
        post "/staging/buildpack_cache/#{droplet_guid}/upload", upload_req
      end

      context "with a valid buildpack cache upload handle" do
        let!(:handle) { StagingsController.create_handle(app_obj.guid) }
        after { StagingsController.destroy_handle(handle) }

        context "with a valid app" do
          it "returns 200" do
            make_request
            last_response.status.should == 200
          end

          it "stores file path in handle.buildpack_cache_upload_path" do
            make_request
            File.exists?(handle.buildpack_cache_upload_path).should be_true
          end
        end

        context "with an invalid app" do
          it "returns 404" do
            make_request("bad")
            last_response.status.should == 404
          end
        end
      end

      context "with an invalid upload handle" do
        it "return 400" do
          make_request
          last_response.status.should == 400
        end
      end
    end

    describe "GET /staging/buildpack_cache/:guid/download" do
      let(:buildpack_cache) { Tempfile.new(app_obj.guid) }

      before do
        buildpack_cache.write("droplet contents")
        buildpack_cache.close

        authorize staging_user, staging_password
      end

      after { FileUtils.rm(buildpack_cache.path) }

      def make_request(droplet_guid=app_obj.guid)
        get "/staging/buildpack_cache/#{droplet_guid}/download"
      end

      context "with a valid buildpack cache" do
        context "when nginx is enabled" do
          it "redirects nginx to serve staged droplet" do
            StagingsController.store_buildpack_cache(app_obj, buildpack_cache.path)

            make_request
            last_response.status.should == 200
            last_response.headers["X-Accel-Redirect"].should match("/cc-droplets/.*/#{app_obj.guid}")
          end
        end

        context "when nginx is disabled" do
          let(:staging_config) do
            original_staging_config.merge({ :nginx => { :use_nginx => false } })
          end

          it "should return the buildpack cache" do
            StagingsController.store_buildpack_cache(app_obj, buildpack_cache.path)

            make_request
            last_response.status.should == 200
            last_response.body.should == "droplet contents"
          end
        end
      end

      context "with a valid buildpack cache but no file" do
        it "should return an error" do
          make_request
          last_response.status.should == 400
        end
      end

      context "with an invalid buildpack cache" do
        it "should return an error" do
          get "/staging/buildpack_cache/bad"
          last_response.status.should == 404
        end
      end
    end

    describe ".delete_droplet" do
      context "when droplet does not exist" do
        it "does nothing" do
          StagingsController.droplet_exists?(app_obj).should == false
          StagingsController.delete_droplet(app_obj)
          StagingsController.droplet_exists?(app_obj).should == false
        end
      end

      context "when droplet exists" do
        let(:droplet) { Tempfile.new(app_obj.guid) }

        context "under the new path format" do
          before { StagingsController.store_droplet(app_obj, droplet.path) }

          it "deletes the droplet if it exists" do
            expect {
              StagingsController.delete_droplet(app_obj)
            }.to change {
              StagingsController.droplet_exists?(app_obj)
            }.from(true).to(false)
          end

          # Fog (local) tries to delete parent directories that might be empty
          # when deleting a file. Sometimes it will fail due to a race
          # since those directories might have been populated in between
          # emptiness check and actual deletion.
          it "does not raise error when it fails to delete directory structure" do
            Fog::Storage::Local::File.any_instance.should_receive(:destroy).and_raise(Errno::ENOTEMPTY)
            StagingsController.delete_droplet(app_obj)
          end
        end

        context "under the old path format" do
          before do
            blobstore = StagingsController.blobstore
            blobstore.cp_from_local(droplet.path, app_obj.guid)
          end

          it "deletes the old droplet" do
            expect {
              StagingsController.delete_droplet(app_obj)
            }.to change {
              StagingsController.droplet_exists?(app_obj)
            }.from(true).to(false)
          end
        end
      end
    end
  end
end
