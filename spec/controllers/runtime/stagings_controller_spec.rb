require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::StagingsController, type: :controller do
    let(:max_staging_runtime) { 120 }
    let(:cc_addr) { "1.2.3.4" }
    let(:cc_port) { 5678 }
    let(:staging_user) { "user" }
    let(:staging_password) { "password" }

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

    let(:app_obj) { App.make :droplet_hash => nil } # explicitly unstaged app

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
            config[:droplets] = {
              :fog_connection => {
                provider: "AWS",
                aws_access_key_id: "secret",
                aws_secret_access_key: "key"
            }}
          end
        end

        before do
          Fog.mock!
        end

        it "returns an AWS url" do
          app_obj.droplet_hash = "abcdefg"

          droplet_file = Tempfile.new(app_obj.guid)
          droplet_file.write("droplet contents")
          droplet_file.close

          droplet = CloudController::Droplet.new(app_obj, StagingsController.blobstore)
          droplet.save(droplet_file.path)

          uri = URI.parse(StagingsController.droplet_download_uri(app_obj))
          expect(uri.host).to eq "cc-droplets.s3.amazonaws.com"
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

      context "with a valid app" do
        it "returns 200" do
          post "/staging/droplets/#{app_obj.guid}/upload", upload_req
          last_response.status.should == 200
        end

        it "updates the app's droplet hash" do
          expect {
            post "/staging/droplets/#{app_obj.guid}/upload", upload_req
          }.to change { app_obj.refresh.droplet_hash }
        end

        it "marks the app as staged" do
          expect {
            post "/staging/droplets/#{app_obj.guid}/upload", upload_req
          }.to change {
            app_obj.refresh.staged?
          }.from(false).to(true)
        end

        it "stores the droplet in the blobstore" do
          expect {
            post "/staging/droplets/#{app_obj.guid}/upload", upload_req
          }.to change {
            droplet = CloudController::Droplet.new(app_obj.refresh, StagingsController.blobstore)
            droplet.exists?
          }.from(false).to(true)
        end
      end

      context "with an invalid app" do
        it "returns 404" do
          post "/staging/droplets/bad-app/upload", upload_req
          last_response.status.should == 404
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
        before do
          app_obj.droplet_hash = "abcdef"
          app_obj.save
        end

        context "with nginx" do
          before { config[:nginx][:use_nginx] = true }

          it "redirects nginx to serve staged droplet" do
            droplet_file = Tempfile.new(app_obj.guid)
            droplet_file.write("droplet contents")
            droplet_file.close

            droplet = CloudController::Droplet.new(app_obj, StagingsController.blobstore)
            droplet.save(droplet_file.path)

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

      context "with a valid app" do
        it "returns 200" do
          post "/staging/buildpack_cache/#{app_obj.guid}/upload", upload_req
          last_response.status.should == 200
        end

        it "stores file path in handle.buildpack_cache_upload_path" do
          expect {
            post "/staging/buildpack_cache/#{app_obj.guid}/upload", upload_req
          }.to change {
            StagingsController.buildpack_cache_blobstore.exists?(
              app_obj.guid
            )
          }.from(false).to(true)
        end
      end

      context "with an invalid app" do
        it "returns 404" do
          post "/staging/buildpack_cache/bad-app/upload", upload_req
          last_response.status.should == 404
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
  end
end
