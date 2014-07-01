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
        let(:user_email) { "user email" }

        let(:event) do
          new_request_attrs = request_attrs.merge("environment_json" => {"foo" => 1})
          app_event_repository.record_app_update(app, user, user_email, new_request_attrs).reload
        end

        it "records the expected fields on the event" do
          expect(event.space).to eq app.space
          expect(event.type).to eq "audit.app.update"
          expect(event.actee).to eq app.guid
          expect(event.actee_type).to eq "app"
          expect(event.actee_name).to eq app.name
          expect(event.actor).to eq user.guid
          expect(event.actor_type).to eq "user"
          expect(event.actor_name).to eq user_email
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

          app_event_repository.record_app_update(app, user, user_email, request_attrs)
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
        let(:user_email) { "user email" }

        it "records the event fields and metadata" do
          event = app_event_repository.record_app_create(app, user, user_email, request_attrs)
          event.reload
          expect(event.type).to eq("audit.app.create")
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq("app")
          expect(event.actee_name).to eq(app.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq("user")
          expect(event.actor_name).to eq(user_email)
          request = event.metadata.fetch("request")
          expect(request).to eq(
                               "name" => "new",
                               "instances" => 1,
                               "memory" => 84,
                               "state" => "STOPPED",
                               "environment_json" => "PRIVATE DATA HIDDEN",
                             )
        end

        it "logs the event" do
          expect(Loggregator).to receive(:emit).with(app.guid, "Created app with guid #{app.guid}")

          app_event_repository.record_app_create(app, user, user_email, request_attrs)
        end
      end

      describe ".record_app_delete" do
        let(:deleting_app) { AppFactory.make }

        let(:user) { User.make }
        let(:user_email) { "user email" }

        it "records an empty changes in metadata" do
          event = app_event_repository.record_app_delete_request(deleting_app, user, user_email, false)
          event.reload
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq("user")
          expect(event.actor_name).to eq(user_email)
          expect(event.type).to eq("audit.app.delete-request")
          expect(event.actee).to eq(deleting_app.guid)
          expect(event.actee_type).to eq("app")
          expect(event.actee_name).to eq(deleting_app.name)
          expect(event.metadata["request"]["recursive"]).to eq(false)
        end

        it "logs the event" do
          expect(Loggregator).to receive(:emit).with(deleting_app.guid, "Deleted app with guid #{deleting_app.guid}")

          app_event_repository.record_app_delete_request(deleting_app, user, user_email, false)
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
          expect(event.actor_name).to eq(exiting_app.name)
          expect(event.actee).to eq(exiting_app.guid)
          expect(event.actee_type).to eq("app")
          expect(event.actee_name).to eq(exiting_app.name)
          expect(event.metadata["unknown_key"]).to eq(nil)
          expect(event.metadata["instance"]).to eq("abc")
          expect(event.metadata["index"]).to eq("2")
          expect(event.metadata["exit_status"]).to eq("1")
          expect(event.metadata["exit_description"]).to eq("shut down")
          expect(event.metadata["reason"]).to eq("evacuation")
        end

        it "logs the event" do
          expect(Loggregator).to receive(:emit).with(exiting_app.guid, "App instance exited with guid #{exiting_app.guid} payload: #{droplet_exited_payload}")

          app_event_repository.create_app_exit_event(exiting_app, droplet_exited_payload)
        end
      end
    end
  end
end
