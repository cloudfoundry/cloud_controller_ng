require "spec_helper"
require "membrane"

module VCAP::CloudController
  module Diego
    describe StagedAppsQuery do
      describe "#all" do
        before do
          5.times do |i|
            app = AppFactory.make(id: i+1, state: "STARTED", package_hash: "package-hash", package_state: "STAGED")
            app.current_droplet.update_start_command("fake-start-command-#{i}")
          end
        end

        it "returns apps that have the desired data" do
          last_app = AppFactory.make({
                                       "id" => 6,
                                       "state" => "STARTED",
                                       "package_hash" => "package-hash",
                                       "disk_quota" => 1_024,
                                       "package_state" => "STAGED",
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

          staged_apps_query = StagedAppsQuery.new(100, 0)
          apps = staged_apps_query.all

          expect(apps.count).to eq(6)


          expect(apps.last.to_json).to match_object(last_app.to_json)
        end

        it "respects the batch_size" do
          app_counts = [3, 5].map do |batch_size|
            staged_apps_query = StagedAppsQuery.new(batch_size, 0)
            apps = staged_apps_query.all
            apps.count
          end

          expect(app_counts).to eq([3, 5])
        end

        it "returns non-intersecting apps across subsequent batches" do
          first_query = StagedAppsQuery.new(3, 0)
          first_batch = first_query.all
          expect(first_batch.count).to eq(3)

          second_query = StagedAppsQuery.new(3, first_batch.last.id)
          second_batch = second_query.all
          expect(second_batch.count).to eq(2)

          expect(second_batch & first_batch).to eq([])
        end

        it "does not return unstaged apps" do
          unstaged_app = App.make(id: 6, state: "STARTED", package_hash: "brown", package_state: "PENDING")

          query = StagedAppsQuery.new(100, 0)
          batch = query.all

          expect(batch).not_to include(unstaged_app)
        end

        it "does not return apps which aren't expected to be started" do
          stopped_app = AppFactory.make(id: 6, state: "STOPPED", package_hash: "brown", package_state: "STAGED")

          query = StagedAppsQuery.new(100, 0)
          batch = query.all

          expect(batch).not_to include(stopped_app)
        end

        it "does not return deleted apps" do
          deleted_app = AppFactory.make(id: 6, state: "STARTED", package_hash: "brown", package_state: "STAGED", deleted_at: DateTime.now)

          query = StagedAppsQuery.new(100, 0)
          batch = query.all

          expect(batch).not_to include(deleted_app)
        end
      end
    end
  end
end
