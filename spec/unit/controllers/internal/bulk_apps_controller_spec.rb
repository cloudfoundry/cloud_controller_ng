require "spec_helper"
require "membrane"
require "json_message"

module VCAP::CloudController
  describe BulkApps do
    before do
      allow_any_instance_of(::CloudController::Blobstore::UrlGenerator)
      .to receive(:droplet_download_url)
      .and_return("http://blobsto.re/droplet")
    end

    before do
      @bulk_user = "bulk_user"
      @bulk_password = "bulk_password"
    end

    describe "GET", "/internal/bulk/apps" do
      before {
        5.times { |i|
          AppFactory.make(id: i+1, state: "STARTED", package_hash: "package-hash", package_state: "STAGED")
        }
      }

      before do
        App.first.environment_json = {
          "FOO" => "bar",
        }
      end

      it "requires authentication" do
        get "/internal/bulk/apps"
        last_response.status.should == 401

        authorize "bar", "foo"
        get "/internal/bulk/apps"
        last_response.status.should == 401
      end

      describe "with authentication" do
        before do
          authorize @bulk_user, @bulk_password
        end

        it "requires a token in query string" do
          get "/internal/bulk/apps", {
              "batch_size" => 20,
          }

          last_response.status.should == 400
        end

        it "returns a populated token for the initial request (which has an empty bulk token)" do
          get "/internal/bulk/apps", {
              "batch_size" => 3,
              "token" => "{}",
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response["token"]).to eq({ "id" => 3 })
        end

        it "returns apps in the response body" do
          get "/internal/bulk/apps", {
              "batch_size" => 20,
              "token" => { id: 2 }.to_json,
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response["apps"].size).to eq(3)
        end

        it "returns apps that have the desired data" do
          last_app = AppFactory.make({
            "id" => 6,
            "state" => "STARTED",
            "package_hash" => "package-hash",
            "disk_quota" => 1_024,
            "environment_json" => {
              "env-key-3" => "env-value-3",
              "env-key-4" => "env-value-4"
            },
            "file_descriptors" => 16_384,
            "instances" => 4,
            "memory" => 1_024,
            "guid" => "app-guid-6",
            "command" => "start-command-6",
            "stack" => Stack.make(name: "stack-6"),
          })

          route1 = Route.make(
              space: last_app.space,
              host: "arsenio",
              domain: SharedDomain.make(name: "lo-mein.com"),
          )
          last_app.add_route(route1)

          route2 = Route.make(
              space: last_app.space,
              host: "conan",
              domain: SharedDomain.make(name: "doe-mane.com"),
          )
          last_app.add_route(route2)

          last_app.version = "app-version-6"
          last_app.save

          get "/internal/bulk/apps", {
              "batch_size" => 100,
              "token" => "{\"id\": 0 }",
          }

          expect(last_response.status).to eq(200)

          expect(decoded_response["apps"].size).to eq(6)


          last_response_app = decoded_response["apps"][5]
          expect(last_response_app.except("environment")).to match_object({
            "disk_mb" => 1_024,
            "file_descriptors" => 16_384,
            "num_instances" => 4,
            "log_guid" => "app-guid-6",
            "memory_mb" => 1_024,
            "process_guid" => "app-guid-6-app-version-6",
            "routes" => ["arsenio.lo-mein.com", "conan.doe-mane.com"],
            "droplet_uri" => "http://blobsto.re/droplet",
            "stack" => "stack-6",
            "start_command" => "start-command-6"
          })

          last_response_app_env = last_response_app["environment"]
          expect(last_response_app_env).to(be_any) { |e| e["name"] == "VCAP_APPLICATION" }
          expect(last_response_app_env).to(be_any) { |e| e["name"] == "MEMORY_LIMIT" }
          expect(last_response_app_env).to(be_any) { |e| e["name"] == "VCAP_SERVICES" }
          expect(last_response_app_env.find { |e| e["name"] == "env-key-3" }["value"]).to eq("env-value-3")
          expect(last_response_app_env.find { |e| e["name"] == "env-key-4" }["value"]).to eq("env-value-4")
        end

        it "respects the batch_size parameter" do
          [3,5].each { |size|
            get "/internal/bulk/apps", {
                "batch_size" => size,
                "token" => "{\"id\":0}",
            }

            expect(last_response.status).to eq(200)
            expect(decoded_response["apps"].size).to eq(size)
          }
        end

        it "returns non-intersecting apps when token is supplied" do
          get "/internal/bulk/apps", {
              "batch_size" => 2,
              "token" => "{\"id\":0}",
          }

          expect(last_response.status).to eq(200)

          saved_apps = decoded_response["apps"].dup
          saved_apps.size.should == 2

          get "/internal/bulk/apps", {
              "batch_size" => 2,
              "token" => Yajl::Encoder.encode(decoded_response["token"]),
          }

          expect(last_response.status).to eq(200)

          new_apps = decoded_response["apps"].dup
          new_apps.size.should == 2
          saved_apps.each do |saved_result|
            new_apps.should_not include(saved_result)
          end
        end

        it "should eventually return entire collection, batch after batch" do
          apps = []
          total_size = App.count

          token = "{}"
          while apps.size < total_size do
            get "/internal/bulk/apps", {
                "batch_size" => 2,
                "token" => Yajl::Encoder.encode(token),
            }

            expect(last_response.status).to eq(200)
            token = decoded_response["token"]
            apps += decoded_response["apps"]
          end

          apps.size.should == total_size
          get "/internal/bulk/apps", {
              "batch_size" => 2,
              "token" => Yajl::Encoder.encode(token),
          }

          expect(last_response.status).to eq(200)
          decoded_response["apps"].size.should == 0
        end

        it "does not return unstaged apps" do
          App.make(id: 6, state: "STARTED", package_hash: "brown", package_state: "PENDING")

          get "/internal/bulk/apps", {
              "batch_size" => App.count,
              "token" => "{}",
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response["apps"].size).to eq(App.count - 1)
        end

        it "does not return apps which aren't expected to be started" do
          AppFactory.make(id: 6, state: "STOPPED", package_hash: "brown", package_state: "STAGED")

          get "/internal/bulk/apps", {
              "batch_size" => App.count,
              "token" => "{}",
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response["apps"].size).to eq(App.count - 1)
        end

        it "does not return deleted apps" do
          AppFactory.make(id: 6, state: "STARTED", package_hash: "brown", package_state: "STAGED", deleted_at: DateTime.now)

          get "/internal/bulk/apps", {
              "batch_size" => App.count,
              "token" => "{}",
          }

          expect(last_response.status).to eq(200)
          expect(decoded_response["apps"].size).to eq(App.count - 1)
        end
      end
    end
  end
end