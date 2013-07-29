require "spec_helper"

module VCAP::CloudController
  describe Models::Event, type: :model do
    let(:space) { Models::Space.make :name => "myspace" }

    subject(:event) do
      Models::Event.make :type => "audit.movie.premiere",
        :actor => "Nicolas Cage",
        :actor_type => "One True God",
        :actee => "John Travolta",
        :actee_type => "Scientologist",
        :timestamp => Time.new(1997, 6, 27),
        :metadata => { "popcorn_price" => "$(arm + leg)" },
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
      expect(event.metadata).to eq({ "popcorn_price" => "$(arm + leg)" })
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
          "timestamp" => Time.new(1997, 6, 27).to_s, # yes local time for now :(
          "metadata" => { "popcorn_price" => "$(arm + leg)" },
          "space_guid" => space.guid
        )
      end
    end

    describe ".record_app_update" do
      let(:app) { Models::App.make(instances: 1) }
      let(:user) { Models::User.make }

      it "records the changes in metadata" do
        app.instances = 2
        app.save

        event = described_class.record_app_update(app, user)
        expect(event.actor_type).to eq("user")
        expect(event.metadata).to eq("changes" => { "instances" => [1, 2] })
      end

      it "does not expose the ENV variables" do
        app.environment_json = { "foo" => 1 }
        app.save

        event = described_class.record_app_update(app, user)
        expect(event.metadata).to eq(
          "changes" => { "environment_json" => ['PRIVATE DATA HIDDEN'] * 2 }
        )
      end
    end
  end
end
