require "spec_helper"
require "repositories/runtime/app_usage_event_repository"

module VCAP::CloudController
  module Repositories::Runtime
    describe AppUsageEventRepository do
      subject(:repository) do
        AppUsageEventRepository.new
      end

      describe "#find" do
        context "when the event exists" do
          let(:event) { AppUsageEvent.make }

          xit "should return the event" do
            expect(repository.find(event.guid)).to eq(event)
          end
        end

        context "when the event does not exist" do
          xit "should return nil" do
            expect(repository.find("does-not-exist")).to be_nil
          end
        end
      end

      describe "#create_from_app" do
        let(:app) { App.make }

        xit "will create an event which matches the app" do
          event = repository.create_from_app(app)
          expect(event).to match_app(app)
        end

        context "when an admin buildpack is associated with the app" do
          before do
            app.admin_buildpack = Buildpack.make
          end

          xit "will create an event that contains the buildpack guid and name" do
            event = repository.create_from_app(app)
            expect(event.buildpack_guid).to eq(app.admin_buildpack.guid)
            expect(event.buildpack_name).to eq(app.admin_buildpack.name)
          end
        end

        context "when a custom buildpack is associated with the app" do
          let (:buildpack_url) { "https://git.example.com/repo.git" }

          before do
            app.buildpack = buildpack_url
          end

          xit "will create an event with the buildpack url as the name" do
            event = repository.create_from_app(app)
            expect(event.buildpack_name).to eq(buildpack_url)
          end

          xit "will create an event without a buildpack guid" do
            event = repository.create_from_app(app)
            expect(event.buildpack_guid).to be_nil
          end
        end

        context "when the DEA doesn't provide optional buildpack information" do
          before do
            app.buildpack = nil
          end

          xit "will create an event that does not contain buildpack name or guid" do
            event = repository.create_from_app(app)
            expect(event.buildpack_guid).to be_nil
            expect(event.buildpack_name).to be_nil
          end
        end

        context "fails to create the event" do
          before do
            app.state = nil
          end

          xit "will raise an error" do
            expect {
              repository.create_from_app(app)
            }.to raise_error
          end
        end
      end

      describe "#purge_and_reseed_started_apps!" do
        let(:app) { App.make(package_hash: Sham.guid) }

        xit "will purge all existing events" do
          3.times{ repository.create_from_app(app) }

          expect {
            repository.purge_and_reseed_started_apps!
          }.to change { AppUsageEvent.count }.to(0)
        end

        context "when there are started apps" do
          before do
            app.state = "STARTED"
            app.save
          end

          xit "creates new events for the started apps" do
            app.state = "STOPPED"
            repository.create_from_app(app)
            app.state = "STARTED"
            repository.create_from_app(app)

            expect {
              repository.purge_and_reseed_started_apps!
            }.to change { AppUsageEvent.count }.from(3).to(1)

            expect(AppUsageEvent.last).to match_app(app)
          end

          context "with associated buidpack information" do
            let (:buildpack) { Buildpack.make }

            before do
              app.buildpack = buildpack
            end

            pending "should preserve the buildpack info in the new event" do
              repository.purge_and_reseed_started_apps!
              event = AppUsageEvent.last

              expect(event.buildpack_guid).to eq(buildpack.guid)
              expect(event.buildpack_name).to eq(buildpack.name)
            end
          end

          xit "should not create two events with the same guid" do
            2.times do
              another_app = AppFactory.make
              another_app.state = "STARTED"
              another_app.save
            end

            repository.purge_and_reseed_started_apps!

            expect(AppUsageEvent.all.map(&:guid).uniq).to have(3).guids
          end
        end
      end

      describe "#delete_events_created_before" do
        before do
          3.times{ repository.create_from_app(App.make) }
        end

        xit "will delete events created before the specified cutoff time" do
          Timecop.travel(Time.now + 5.minutes) do
            app = App.make
            repository.create_from_app(app)

            expect {
              repository.delete_events_created_before(Time.now - 4.minutes)
            }.to change { AppUsageEvent.count }.from(4).to(1)

            expect(AppUsageEvent.last).to match_app(app)
          end
        end
      end
    end
  end
end
