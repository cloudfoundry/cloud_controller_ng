require "spec_helper"

module VCAP::CloudController
  describe AppBitsUploadController do
    describe "PUT /v2/app/:id/bits" do
      let(:app_obj) do
        AppFactory.make(droplet_hash: nil, package_hash: nil, package_state: "PENDING")
      end

      let(:tmpdir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(tmpdir) }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, "file.zip")
        TestZip.create(zip_name, 1, 1024)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:headers) { headers_for(user) }

      def make_request
        put "/v2/apps/#{app_obj.guid}/bits", req_body, headers
      end

      context "as an admin" do
        let(:headers) { admin_headers }
        let(:req_body) { {resources: "[]", application: valid_zip} }

        it "allows upload even if app_bits_upload flag is disabled" do
          FeatureFlag.make(name: 'app_bits_upload', enabled: false)
          make_request
          expect(last_response.status).to eq(201)
        end
      end

      context "as a developer" do
        let(:user) { make_developer_for_space(app_obj.space) }

        context "when the app_bits_upload feature flag is disabled" do
          let(:req_body) { {resources: "[]", application: valid_zip} }

          before do
            FeatureFlag.make(name: 'app_bits_upload', enabled: false, error_message: nil)
            make_request
            app_obj.refresh
          end

          it "returns FeatureDisabled and does not upload" do
            expect(last_response.status).to eq(403)
            expect(decoded_response["error_code"]).to match(/FeatureDisabled/)
            expect(decoded_response["description"]).to match(/app_bits_upload/)

            expect(app_obj.package_hash).to be_nil
          end

          it "does not modify the package state" do
            expect(app_obj.package_state).not_to eq "FAILED"
          end
        end

        context "when the app_bits_upload feature flag is enabled" do
          before do
            FeatureFlag.make(name: 'app_bits_upload', enabled: true)
          end

          context "with an empty request" do
            let(:req_body) { {} }

            it "fails to upload" do
              make_request

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)["description"]).to include("missing :resources")

              app_obj.refresh
              expect(app_obj.package_hash).to be_nil
              expect(app_obj.package_state).to eq "FAILED"
            end
          end

          context "with empty resources and no application" do
            let(:req_body) { {resources: "[]"} }

            it "fails to upload" do
              make_request

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)["description"]).to include("Could not zip the package")

              app_obj.refresh
              expect(app_obj.package_hash).to be_nil
              expect(app_obj.package_state).to eq "FAILED"
            end
          end

          context "with at least one resource and no application" do
            let(:req_body) { {resources: JSON.dump([{"fn" => "lol", "sha1" => "abc", "size" => 2048}])} }

            it "succeeds to upload" do
              make_request
              expect(last_response.status).to eq(201)
              expect(app_obj.refresh.package_hash).to_not be_nil
            end
          end

          context "with no resources and application" do
            let(:req_body) { {:application => valid_zip} }

            it "fails to upload" do
              make_request

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)["description"]).to include("missing :resources")

              app_obj.refresh
              expect(app_obj.package_hash).to be_nil
              expect(app_obj.package_state).to eq "FAILED"
            end
          end

          context "with empty resources" do
            let(:req_body) do
              {resources: "[]", application: valid_zip}
            end

            it "succeeds to upload" do
              make_request
              expect(last_response.status).to eq(201)
              expect(app_obj.refresh.package_hash).to_not be_nil
            end
          end

          context "with a bad zip file" do
            let(:bad_zip) { Rack::Test::UploadedFile.new(Tempfile.new("bad_zip")) }
            let(:req_body) do
              {resources: "[]", application: bad_zip}
            end

            it "fails to upload" do
              make_request

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)["description"]).to include("Unzipping had errors")

              app_obj.refresh
              expect(app_obj.package_hash).to be_nil
              expect(app_obj.package_state).to eq "FAILED"
            end
          end

          context "with a valid zip file" do
            let(:req_body) do
              {resources: "[]", application: valid_zip}
            end

            it "succeeds to upload" do
              make_request
              expect(last_response.status).to eq(201)
              expect(app_obj.refresh.package_hash).to_not be_nil
            end

            context "when the upload will finish after the auth token expires" do
              before do
                TestConfig.override(app_bits_upload_grace_period_in_seconds: 200)
              end

              context "but the upload will finish inside the grace period" do
                it "succeeds" do
                  headers = headers_for(user)

                  Timecop.travel(Time.now + 1.week + 100.seconds) do
                    put "/v2/apps/#{app_obj.guid}/bits", req_body, headers
                  end
                  expect(last_response.status).to eq(201)
                end
              end

              context "and the upload will finish after the grace period" do
                it "fails to authorize the upload" do
                  headers = headers_for(user)

                  Timecop.travel(Time.now + 1.week + 10000.seconds) do
                    put "/v2/apps/#{app_obj.guid}/bits", req_body, headers
                  end
                  expect(last_response.status).to eq(401)
                end
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

        it "returns 403" do
          make_request
          expect(last_response.status).to eq(403)
        end
      end

      context "when running async" do
        let(:user) { make_developer_for_space(app_obj.space) }
        let(:req_body) do
          {resources: "[]", application: valid_zip}
        end

        before do
          TestConfig.override(index: 99, name: "api_z1")
        end

        it "creates a delayed job" do
          expect {
            put "/v2/apps/#{app_obj.guid}/bits?async=true", req_body, headers_for(user)
          }.to change {
            Delayed::Job.count
          }.by(1)

          response_body = JSON.parse(last_response.body, :symbolize_names => true)
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
