require "spec_helper"

module VCAP::CloudController
  describe AppBitsUploadController, type: :controller do
    describe "PUT /v2/app/:id/bits" do
      let(:app_obj) do
        AppFactory.make droplet_hash: nil, package_state: "PENDING"
      end

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

        it "returns valid JSON" do
          make_request
          expect { JSON.parse(last_response.body) }.not_to raise_error
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

        it "returns valid JSON" do
          make_request
          expect { JSON.parse(last_response.body) }.not_to raise_error
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
          let(:req_body) { {resources: "[]"} }
          it_fails_to_upload
        end

        context "with at least one resource and no application" do
          let(:req_body) { {resources: JSON.dump([{"fn" => "lol", "sha1" => "abc", "size" => 2048}])} }
          it_succeeds_to_upload
        end

        context "with no resources and application" do
          let(:req_body) { {:application => valid_zip} }
          it_fails_to_upload
        end

        context "with empty resources" do
          let(:req_body) do
            {resources: "[]", application: valid_zip}
          end
          it_succeeds_to_upload
        end

        context "with a bad zip file" do
          let(:bad_zip) { Rack::Test::UploadedFile.new(Tempfile.new("bad_zip")) }
          let(:req_body) do
            {resources: "[]", application: bad_zip}
          end
          it_fails_to_upload
        end

        context "with a valid zip file" do
          let(:req_body) do
            {resources: "[]", application: valid_zip}
          end
          it_succeeds_to_upload

          context "when the upload will finish after the auth token expires" do
            before do
              config_override(app_bits_upload_grace_period_in_seconds: 200)
            end

            context "but the upload will finish inside the grace period" do
              it "succeeds" do
                headers = headers_for(user)

                Timecop.travel(Time.now + 1.week + 100.seconds) do
                  put "/v2/apps/#{app_obj.guid}/bits", req_body, headers
                end
                last_response.status.should == 201
              end
            end

            context "and the upload will finish after the grace period" do
              it "fails to authorize the upload" do
                headers = headers_for(user)

                Timecop.travel(Time.now + 1.week + 10000.seconds) do
                  put "/v2/apps/#{app_obj.guid}/bits", req_body, headers
                end
                last_response.status.should == 401
              end
            end
          end
        end
      end

      context "as a non-developer" do
        let(:user) { make_user_for_space(app_obj.space) }
        let(:req_body) do
          {resources: "[]", application: valid_zip}
        end
        it_forbids_upload
      end

      context "when running async" do
        let(:user) { make_developer_for_space(app_obj.space) }
        let(:req_body) do
          {resources: "[]", application: valid_zip}
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

          response_body = JSON.parse(last_response.body, :symbolize_keys => true)
          job = Delayed::Job.last
          expect(job.handler).to include(app_obj.guid)
          expect(job.queue).to eq("cc-api_z1-99")
          expect(job.guid).not_to be_nil
          expect(last_response.status).to eq 201
          expect(response_body).to eq({
                                          :metadata => {
                                              :guid => job.guid,
                                              :created_at => job.created_at.iso8601,
                                              :url => "/v2/jobs/#{job.guid}"
                                          },
                                          :entity => {
                                              :guid => job.guid,
                                              :status => "queued"
                                          }
                                      })
        end
      end
    end
  end
end