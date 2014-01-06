require "spec_helper"

module VCAP::CloudController
  module Repositories::Runtime
    describe AppEventRepository do
      subject(:app_event_repository) do
        AppEventRepository.new
      end

      describe ".record_app_update" do
        let(:request_attrs) do
          {"name" => "old", "instances" => 1, "memory" => 84, "state" => "STOPPED"}
        end

        let(:app) { AppFactory.make(instances: 2, memory: 99) }
        let(:user) { User.make }

        let(:event) do
          new_request_attrs = request_attrs.merge("environment_json" => {"foo" => 1})
          app_event_repository.record_app_update(app, user, new_request_attrs)
        end

        it "does not expose the ENV variables" do
          request = event.metadata.fetch("request")
          expect(request).to include("environment_json" => "PRIVATE DATA HIDDEN")
        end

        it "contains user request information" do
          request = event.metadata.fetch("request")
          expect(request).to include(
                               "name" => "old",
                               "instances" => 1,
                               "memory" => 84,
                               "state" => "STOPPED"
                             )
        end

        it "logs the event" do
          expect(Loggregator).to receive(:emit).with(app.guid, "Updated app with guid #{app.guid} (#{request_attrs.to_s})")

          app_event_repository.record_app_update(app, user, request_attrs)
        end
      end

      describe ".record_app_create" do
        let(:request_attrs) do
          {
            "name" => "new",
            "instances" => 1,
            "memory" => 84,
            "state" => "STOPPED",
            "environment_json" => {"super" => "secret "}
          }
        end

        let(:app) do
          AppFactory.make(request_attrs)
        end

        let(:user) { User.make }

        it "records the changes in metadata" do
          event = app_event_repository.record_app_create(app, user, request_attrs)
          expect(event.actor_type).to eq("user")
          expect(event.type).to eq("audit.app.create")
          request = event.metadata.fetch("request")
          expect(request).to eq(
                               "name" => "new",
                               "instances" => 1,
                               "memory" => 84,
                               "state" => "STOPPED",
                               "environment_json" => "PRIVATE DATA HIDDEN",
                             )
        end
      end

      describe ".record_app_delete" do
        let(:deleting_app) { AppFactory.make }

        let(:user) { User.make }

        it "records an empty changes in metadata" do
          event = app_event_repository.record_app_delete_request(deleting_app, user, false)
          expect(event.actor_type).to eq("user")
          expect(event.type).to eq("audit.app.delete-request")
          expect(event.actee).to eq(deleting_app.guid)
          expect(event.actee_type).to eq("app")
          expect(event.metadata["request"]["recursive"]).to eq(false)
        end
      end

      describe ".create_app_exit_event" do
        let(:exiting_app) { AppFactory.make }
        let(:droplet_exited_payload) {
          {
            "instance" => "abc",
            "index" => "2",
            "exit_status" => "1",
            "exit_description" => "shut down",
            "reason" => "evacuation",
            "unknown_key" => "something"
          }
        }

        it "creates a new app exit event" do
          event = app_event_repository.create_app_exit_event(exiting_app, droplet_exited_payload)
          expect(event.type).to eq("app.crash")
          expect(event.actor).to eq(exiting_app.guid)
          expect(event.actor_type).to eq("app")
          expect(event.actee).to eq(exiting_app.guid)
          expect(event.actee_type).to eq("app")
          expect(event.metadata["unknown_key"]).to eq(nil)
          expect(event.metadata["instance"]).to eq("abc")
          expect(event.metadata["index"]).to eq("2")
          expect(event.metadata["exit_status"]).to eq("1")
          expect(event.metadata["exit_description"]).to eq("shut down")
          expect(event.metadata["reason"]).to eq("evacuation")
        end
      end
    end
  end
end
