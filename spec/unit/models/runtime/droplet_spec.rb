require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Droplet, type: :model do
    let(:app) do
      AppFactory.make(droplet_hash: nil)
    end

    let(:blobstore) do
      CloudController::DependencyLocator.instance.droplet_blobstore
    end

    before do
      #force evaluate the blobstore let before stubbing out dependency locator
      blobstore
      allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).
        and_return(blobstore)
    end

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :app }
    end

    describe "Validations" do
      it { is_expected.to validate_presence :app }
      it { is_expected.to validate_presence :droplet_hash }
    end

    it "creates successfully with an app and a droplet hash" do
      app = AppFactory.make
      expect(Droplet.new(app: app, droplet_hash: Sham.guid).save).to be
    end

    it "has a create_at timestamp used in ordering droplets for an app" do
      app.add_new_droplet("hash_1")
      app.save
      expect(app.droplets.first.created_at).to be
    end

    context "when deleting droplets" do
      it "destroy drives delete_from_blobstore" do
        app = AppFactory.make
        droplet = app.current_droplet
        enqueuer = double("Enqueuer", enqueue: true)
        expect(Jobs::Enqueuer).to receive(:new).with(
          Jobs::Runtime::DropletDeletion.new(droplet.new_blobstore_key, droplet.old_blobstore_key),
          queue: "cc-generic"
        ).and_return(enqueuer)
        droplet.destroy
      end
    end

    describe "app deletion" do
      it "deletes the droplet when the app is destroyed" do
        app.add_new_droplet("hash_1")
        app.add_new_droplet("new_hash")
        app.save
        expect(app.droplets).to have(2).items
        expect {
          app.destroy
        }.to change {
          Droplet.count
        }.by(-2)
      end
    end

    describe "blobstore key" do
      it "combines app guid and the given digests" do
        expect(Droplet.droplet_key("abc", "xyz")).to eql("abc/xyz")
      end
    end
  end
end
