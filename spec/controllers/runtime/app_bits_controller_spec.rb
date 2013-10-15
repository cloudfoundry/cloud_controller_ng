require "spec_helper"

module VCAP::CloudController
  describe AppBitsController, type: :controller do
    describe "PUT /v2/app/:id/bits" do
      let(:app_obj) { AppFactory.make :droplet_hash => nil, :package_state => "PENDING" }

      let(:tmpdir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(tmpdir) }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, "file.zip")
        create_zip(zip_name, 1)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      def self.it_forbids_upload
        it "returns 403" do
          put "/v2/apps/#{app_obj.guid}/bits", req_body, headers_for(user)
          last_response.status.should == 403
        end
      end

      def self.it_succeeds_to_upload
        it "returns 201" do
          make_request
          last_response.status.should == 201
        end

        it "updates package hash" do
          expect {
            make_request
          }.to change { app_obj.refresh.package_hash }.from(nil)
        end
      end

      def self.it_fails_to_upload
        it "returns 400" do
          make_request
          last_response.status.should == 400
        end

        it "does not update package hash" do
          expect {
            make_request
          }.to_not change { app_obj.refresh.package_hash }.from(nil)
        end

        it "changes the app package_state to FAILED" do
          expect {
            make_request
          }.to change { app_obj.refresh.package_state }.from("PENDING").to("FAILED")
        end
      end

      def make_request
        put "/v2/apps/#{app_obj.guid}/bits", req_body, headers_for(user)
      end

      context "as a developer" do
        let(:user) { make_developer_for_space(app_obj.space) }

        context "with an empty request" do
          let(:req_body) { {} }
          it_fails_to_upload
        end

        context "with empty resources and no application" do
          let(:req_body) { {:resources => "[]"} }
          it_fails_to_upload
        end

        context "with at least one resource and no application" do
          let(:req_body) { {:resources => JSON.dump([{"fn" => "lol", "sha1" => "abc", "size" => 2048}])} }
          it_succeeds_to_upload
        end

        context "with no resources and application" do
          let(:req_body) { { :application => valid_zip } }
          it_fails_to_upload
        end

        context "with empty resources" do
          let(:req_body) {{
            :resources => "[]",
            :application => valid_zip
          }}
          it_succeeds_to_upload
        end

        context "with a bad zip file" do
          let(:bad_zip) { Rack::Test::UploadedFile.new(Tempfile.new("bad_zip")) }
          let(:req_body) {{
            :resources => "[]",
            :application => bad_zip,
          }}
          it_fails_to_upload
        end

        context "with a valid zip file" do
          let(:req_body) do
            {
              resources: "[]",
              :application => valid_zip,
            }
          end
          it_succeeds_to_upload
        end
      end

      context "as a non-developer" do
        let(:user) { make_user_for_space(app_obj.space) }
        let(:req_body) {{
          :resources => "[]",
          :application => valid_zip,
        }}
        it_forbids_upload
      end

      context "when running async" do
        let(:user) { make_developer_for_space(app_obj.space) }
        let(:req_body) do
          {
            resources: "[]",
            application: valid_zip,
          }
        end

        before do
          config_override(:index => 99, :name => "api_z1")
        end

        it "creates a delayed job" do
          expect {
            put "/v2/apps/#{app_obj.guid}/bits?async=true", req_body, headers_for(user)
          }.to change {
            Delayed::Job.count
          }.by(1)

          job = Delayed::Job.last
          expect(job.handler).to include(app_obj.guid)
          expect(job.queue).to eq("cc-api_z1-99")
          expect(job.guid).not_to be_nil
          expect(last_response.status).to eq 201
          expect(last_response.body).to eq({
            :metadata => {
              :guid => job.guid,
              :created_at => job.created_at.iso8601,
              :url => "/v2/jobs/#{job.guid}"
            },
            :entity => {
              :guid => job.guid,
              :status => "queued"
            }
          }.to_json)
        end
      end
    end

    describe "GET /v2/app/:id/download" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:app_obj) { AppFactory.make }
      let(:app_obj_without_pkg) { AppFactory.make }
      let(:user) { make_user_for_space(app_obj.space) }
      let(:developer) { make_developer_for_space(app_obj.space) }
      let(:developer2) { make_developer_for_space(app_obj_without_pkg.space) }

      before do
        config
        tmpdir = Dir.mktmpdir
        zipname = File.join(tmpdir, "test.zip")
        create_zip(zipname, 10, 1024)
        AppBitsPackerJob.new(app_obj.guid, zipname, []).perform
        FileUtils.rm_rf(tmpdir)
      end

      context "when app is local" do
        let(:workspace) { Dir.mktmpdir }
        let(:blobstore_config) do
          {
            :packages => {
              :fog_connection => {
                :provider => "Local",
                :local_root => Dir.mktmpdir("packages", workspace)
              },
              :app_package_directory_key => "cc-packages",
            },
            :resource_pool => {
              :resource_directory_key => "cc-resources",
              :fog_connection => {
                :provider => "Local",
                :local_root => Dir.mktmpdir("resourse_pool", workspace)
              }
            },
          }
        end

        before do
          Fog.unmock!
          @old_config = config
          config_override(blobstore_config)
          guid = app_obj.guid
          tmpdir = Dir.mktmpdir
          zipname = File.join(tmpdir, "test.zip")
          create_zip(zipname, 10, 1024)
          AppBitsPackerJob.new(guid, zipname, []).perform
        end

        after do
          config_override(@old_config)
        end

        context "when using nginx" do
          it "redirects to correct nginx URL" do
            get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(developer)
            last_response.status.should == 200
            app_bit_path = last_response.headers.fetch("X-Accel-Redirect")
            File.exists?(File.join(workspace, app_bit_path))
          end
        end
      end

      context "dev app download" do
        it "should return 404 for an app without a package" do
          get "/v2/apps/#{app_obj_without_pkg.guid}/download", {}, headers_for(developer2)
          last_response.status.should == 404
        end

        it "should return 302 for valid packages" do
          get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(developer)
          last_response.status.should == 302
        end

        it "should return 404 for non-existent apps" do
          get "/v2/apps/abcd/download", {}, headers_for(developer)
          last_response.status.should == 404
        end
      end

      context "user app download" do
        it "should return 403" do
           get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(user)
           last_response.status.should == 403
        end
      end
    end
  end
end
