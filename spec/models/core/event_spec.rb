require "spec_helper"

module VCAP::CloudController
  describe Event, type: :model do
    let(:space) { Space.make :name => "myspace" }

    subject(:event) do
      Event.make :type => "audit.movie.premiere",
        :actor => "Nicolas Cage",
        :actor_type => "One True God",
        :actee => "John Travolta",
        :actee_type => "Scientologist",
        :timestamp => Time.new(1997, 6, 27),
        :metadata => {"popcorn_price" => "$(arm + leg)"},
        :space => space
    end

    it "has an actor" do
      expect(event.actor).to eq("Nicolas Cage")
    end

    it "has an actor type" do
      expect(event.actor_type).to eq("One True God")
    end

    it "has an actee" do
      expect(event.actee).to eq("John Travolta")
    end

    it "has an actee type" do
      expect(event.actee_type).to eq("Scientologist")
    end

    it "has a timestamp" do
      expect(event.timestamp).to eq(Time.new(1997, 6, 27))
    end

    it "has a data bag" do
      expect(event.metadata).to eq({"popcorn_price" => "$(arm + leg)"})
    end

    it "belongs to a space" do
      expect(event.space).to eq(space)
    end

    describe "#to_json" do
      it "serializes with type, actor, actee, timestamp, metadata" do
        json = Yajl::Parser.parse(event.to_json)

        expect(json).to eq(
          "type" => "audit.movie.premiere",
          "actor" => "Nicolas Cage",
          "actor_type" => "One True God",
          "actee" => "John Travolta",
          "actee_type" => "Scientologist",
          "timestamp" => Time.new(1997, 6, 27).iso8601,
          "metadata" => {"popcorn_price" => "$(arm + leg)"},
          "space_guid" => space.guid
        )
      end
    end

    describe ".record_app_update" do
      let(:app) { App.make(name: 'old', instances: 1, memory: 84, state: "STOPPED") }
      let(:user) { User.make }

      it "records the changes in metadata" do
        app.instances = 2
        app.memory = 42
        app.state = 'STARTED'
        app.package_hash = 'abc'
        app.package_state = 'STAGED'
        app.name = 'new'
        app.save

        event = described_class.record_app_update(app, user)
        expect(event.type).to eq("audit.app.update")
        expect(event.actor_type).to eq("user")
        changes = event.metadata.fetch("changes")
        expect(changes).to eq(
          "name" => %w(old new),
          "instances" => [1, 2],
          "memory" => [84, 42],
          "state" => %w(STOPPED STARTED),
        )
      end

      it "does not expose the ENV variables" do
        app.environment_json = {"foo" => 1}
        app.save

        event = described_class.record_app_update(app, user)
        changes = event.metadata.fetch("changes")
        expect(changes).to eq(
          "encrypted_environment_json" => ['PRIVATE DATA HIDDEN'] * 2
        )
      end

      it "records the current footprints of the app" do
        app.instances = 2
        app.memory = 42
        app.package_hash = 'abc'
        app.package_state = 'STAGED'
        app.save

        event = described_class.record_app_update(app, user)
        footprints = event.metadata.fetch("footprints")
        expect(footprints).to eq(
          "instances" => 2,
          "memory" => 42,
        )
      end
    end

    describe ".record_app_create" do
      let(:app) do
        App.make(
          name: 'new', instances: 1, memory: 84,
          state: "STOPPED", environment_json: { "super" => "secret "})
      end

      let(:user) { User.make }

      it "records the changes in metadata" do
        event = described_class.record_app_create(app, user)
        expect(event.actor_type).to eq("user")
        expect(event.type).to eq("audit.app.create")
        changes = event.metadata.fetch("changes")
        expect(changes).to eq(
          "name" => "new",
          "instances" => 1,
          "memory" => 84,
          "state" => "STOPPED",
          "encrypted_environment_json" => "PRIVATE DATA HIDDEN",
        )
      end
    end

    describe ".record_app_delete" do
      let(:deleting_app) { App.make }

      let(:user) { User.make }

      it "records an empty changes in metadata" do
        event = described_class.record_app_delete(deleting_app, user)
        expect(event.actor_type).to eq("user")
        expect(event.type).to eq("audit.app.delete")
        expect(event.actee).to eq(deleting_app.guid)
        expect(event.actee_type).to eq("app")
        expect(event.metadata["changes"]).to eq(nil)
      end
    end
  end
end
