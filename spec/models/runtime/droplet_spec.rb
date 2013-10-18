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
      CloudController::DependencyLocator.instance.stub(:droplet_blobstore).
        and_return(blobstore)
    end

    def tmp_file_with_content(content = Sham.guid)
      file = Tempfile.new("a_file")
      file.write(content)
      file.flush
      @files ||= []
      @files << file
      file
    end

    after { @files.each { |file| file.unlink } if @files }

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
      app.add_new_droplet("hash_1")
      app.save
      expect(app.droplets.first.created_at).to be
    end

    context "when deleting droplets" do
      it "destroy drives delete_from_blobstore" do
        app = AppFactory.make
        droplet = app.current_droplet
        Delayed::Job.should_receive(:enqueue).with(
          DropletDeletionJob.new(droplet.new_blobstore_key, droplet.old_blobstore_key),
          queue: "cc-generic"
        )
        droplet.destroy
      end
    end

    describe "app deletion" do
      it "deletes the droplet when the app is soft deleted" do
        app.add_new_droplet("hash_1")
        app.add_new_droplet("new_hash")
        app.save
        expect(app.droplets).to have(2).items
        expect {
          app.soft_delete
        }.to change {
          Droplet.count
        }.by(-2)
      end

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