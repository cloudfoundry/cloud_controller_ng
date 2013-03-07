# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::LegacyStaging do
    let(:max_staging_runtime) { 120 }
    let(:cc_addr) { "1.2.3.4" }
    let(:cc_port) { 5678 }
    let(:staging_user) { "user" }
    let(:staging_password) { "password" }
    let(:app_guid) { "abc" }
    let(:staging_config) do
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
            :local_root => Dir.mktmpdir
          }
        },
        :packages => {
          :fog_connection => {
            :provider => "Local",
            :local_root => Dir.mktmpdir
          }
        },
        :droplets => {
          :fog_connection => {
            :provider => "Local",
            :local_root => Dir.mktmpdir
          }
        }
      }
    end

    before do
      Fog.unmock!
      config_override(staging_config)
      config
    end

    describe "#create_handle" do
      let(:handle_id) { Sham.guid }

      context "when handle does not exist for given id" do
        it "creates handle with id and empty upload path" do
          LegacyStaging.create_handle(handle_id).tap do |h|
            h.id.should == handle_id
            h.upload_path.should be_nil
          end
        end

        it "remembers handle" do
          expect {
            LegacyStaging.create_handle(handle_id)
          }.to change { LegacyStaging.lookup_handle(handle_id) }.from(nil)
        end
      end

      context "when handle exists for given id" do
        before { LegacyStaging.create_handle(handle_id) }

        it "does not allow duplicate handle id's" do
          expect {
            LegacyStaging.create_handle(handle_id)
          }.to raise_error(Errors::StagingError, /staging already in progress/)
        end
      end
    end

    describe "#destroy_handle" do
      let(:handle_id) { Sham.guid }
      let!(:handle) { LegacyStaging.create_handle(handle_id) }

      context "when the handle exists" do
        def self.it_destroys_handle
          it "destroys the handle" do
            expect {
              LegacyStaging.destroy_handle(handle)
            }.to change { LegacyStaging.lookup_handle(handle_id) }.from(handle).to(nil)
          end
        end

        context "when upload_path is set" do
          let(:tmp_file) { Tempfile.new("temp_file") }
          before { handle.upload_path = tmp_file.path }

          context "and the upload path exists" do
            it_destroys_handle

            it "destroys the uploaded file" do
              expect {
                LegacyStaging.destroy_handle(handle)
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
      end

      context " when the handle does not exist" do
        it "does nothing" do
          LegacyStaging.destroy_handle(handle)
        end
      end
    end

    describe "app_uri" do
      it "should return a uri to our cc" do
        uri = LegacyStaging.app_uri(app_guid)
        uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/apps/#{app_guid}"
      end
    end

    describe "droplet_upload_uri" do
      it "should return a uri to our cc" do
        uri = LegacyStaging.droplet_upload_uri(app_guid)
        uri.should == "http://#{staging_user}:#{staging_password}@#{cc_addr}:#{cc_port}/staging/droplets/#{app_guid}"
      end
    end

    shared_examples "staging bad auth" do |verb|
      it "should return 403 for bad credentials" do
        authorize "hacker", "sw0rdf1sh"
        send(verb, "/staging/apps/#{app_obj.guid}")
        last_response.status.should == 403
      end
    end

    describe "GET /staging/apps/:id" do
      let(:app_obj) { Models::App.make }
      let(:app_obj_without_pkg) { Models::App.make }
      let(:app_package_path) { AppPackage.package_path(app_obj.guid) }

      before do
        config_override(staging_config)
        authorize staging_user, staging_password
      end

      it "should succeed for valid packages" do
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

      include_examples "staging bad auth", :get
    end

    describe "POST /staging/droplets/:id" do
      let(:app_obj) { Models::App.make }
      let(:tmpfile) { Tempfile.new("droplet.tgz") }
      let(:upload_req) do
        { :upload => { :droplet => Rack::Test::UploadedFile.new(tmpfile) } }
      end

      before do
        config_override(staging_config)
        authorize staging_user, staging_password
      end

      def make_request(droplet_guid=app_obj.guid)
        post "/staging/droplets/#{droplet_guid}", upload_req
      end

      context "with a valid upload handle" do
        let!(:handle) { LegacyStaging.create_handle(app_obj.guid) }
        after { LegacyStaging.destroy_handle(handle) }

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

      include_examples "staging bad auth", :post
    end

    describe "GET /staged_droplets/:id" do
      let(:app_obj) { Models::App.make }

      before do
        config_override(staging_config)
        authorize staging_user, staging_password
      end

      context "with a valid droplet" do
        xit "should return the droplet" do
          droplet = Tempfile.new(app_obj.guid)
          droplet.write("droplet contents")
          droplet.close
          LegacyStaging.store_droplet(app_obj.guid, droplet.path)

          get "/staged_droplets/#{app_obj.guid}"
          last_response.status.should == 200
          last_response.body.should == "droplet contents"
        end

        it "redirects nginx to serve staged droplet" do
          droplet = Tempfile.new(app_obj.guid)
          droplet.write("droplet contents")
          droplet.close
          LegacyStaging.store_droplet(app_obj.guid, droplet.path)

          get "/staged_droplets/#{app_obj.guid}"
          last_response.status.should == 200
          last_response.headers["X-Accel-Redirect"].should match("/cc-droplets/.*/#{app_obj.guid}")
        end
      end

      context "with a valid app but no droplet" do
        it "should return an error" do
          get "/staged_droplets/#{app_obj.guid}"
          last_response.status.should == 400
        end
      end

      context "with an invalid app" do
        it "should return an error" do
          get "/staged_droplets/bad"
          last_response.status.should == 404
        end
      end
    end
  end
end
