require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Droplet, type: :model do
    it "creates successfully with an app and a droplet hash" do
      app = AppFactory.make
      expect(Droplet.new(app: app, droplet_hash: Sham.guid).save).to be
    end

    describe "validation" do
      it "requires an app" do
        expect { Droplet.make(app: nil) }.to raise_error Sequel::ValidationFailed, /app presence/
      end

      it "requires an droplet_hash" do
        expect { Droplet.make(:droplet_hash => nil) }.to raise_error Sequel::ValidationFailed, /droplet_hash presence/
      end
    end

    it "has a create_at timestamp used in ordering droplets for an app" do
      droplet = Droplet.make
      expect(droplet.created_at).to be
    end
  end
end