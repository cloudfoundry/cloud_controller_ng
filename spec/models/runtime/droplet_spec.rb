require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Droplet, type: :model do
    let(:app) do
      AppFactory.make(droplet_hash: nil)
    end

    it "creates successfully with an app and a droplet hash" do
      app = AppFactory.make
      expect(Droplet.new(app: app, droplet_hash: Sham.guid).save).to be
    end

    describe "validation" do
      it "requires an app" do
        expect { Droplet.new(app: nil).save }.to raise_error Sequel::ValidationFailed, /app presence/
      end

      it "requires an droplet_hash" do
        expect { Droplet.new(droplet_hash: nil, app: app).save }.to raise_error Sequel::ValidationFailed, /droplet_hash presence/
      end
    end

    it "has a create_at timestamp used in ordering droplets for an app" do
      app.droplet_hash = "hash_1"
      app.save
      expect(app.droplets.first.created_at).to be
    end

    it "deletes the droplet when the app is soft deleted" do
      app.droplet_hash = "hash_1"
      app.droplet_hash = "new_hash"
      app.save
      expect(app.droplets).to have(2).items
      expect{
        app.soft_delete
      }.to change{
        Droplet.count
      }.by(-2)
    end

    it "deletes the droplet when the app is destroyed" do
      app.droplet_hash = "hash_1"
      app.droplet_hash = "new_hash"
      app.save
      expect(app.droplets).to have(2).items
      expect{
        app.destroy
      }.to change{
        Droplet.count
      }.by(-2)
    end
  end
end