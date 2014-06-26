require "spec_helper"
require "tmpdir"

describe CloudController::DropletUploader do
  let(:app) do
    VCAP::CloudController::AppFactory.make(droplet_hash: "droplet_hash")
  end

  let(:blobstore) do
    CloudController::DependencyLocator.instance.droplet_blobstore
  end

  subject { described_class.new(app, blobstore) }

  describe "#execute" do
    include TempFileCreator

    it "add a new app droplet" do
      old_size = app.droplets.size
      expect { subject.upload(temp_file_with_content.path) }.to change {
        app.droplet_hash
      }
      expect(app.droplets.size).to eql(old_size + 1)
    end

    it "does not create a new droplet if the upload fails" do
      allow(blobstore).to receive(:cp_to_blobstore).and_raise "Upload failed"
      expect {
        expect {
          subject.upload(temp_file_with_content.path)
        }.to raise_error
      }.not_to change {
        app.reload.droplets.size
      }
    end

    it "deletes old droplets" do
      droplets_to_keep = 2
      expect(app.droplets).to have(1).items

      Timecop.travel(Date.today + 2) do
        file = temp_file_with_content("droplet version 2")
        subject.upload(file.path)
        expect(app.reload.droplets).to have(droplets_to_keep).items
      end

      droplet_dest = Tempfile.new("downloaded_droplet")
      app.current_droplet.download_to(droplet_dest.path)
      expect(droplet_dest.read).to eql("droplet version 2")

      Timecop.travel(Date.today + 3) do
        subject.upload(temp_file_with_content("droplet version 3").path)
        expect(app.reload.droplets).to have(droplets_to_keep).items
      end

      droplet_dest = Tempfile.new("downloaded_droplet")
      app.current_droplet.download_to(droplet_dest.path)
      expect(droplet_dest.read).to eql("droplet version 3")
    end

    it "deletes the number of old droplets specified in droplets_to_keep" do
      droplets_to_keep = 1
      expect(app.droplets).to have(1).items
      old_droplet = app.droplets.first

      Timecop.travel(Date.today + 2) do
        subject.upload(temp_file_with_content("droplet version 2").path, droplets_to_keep)
        expect(app.reload.droplets).to have(droplets_to_keep).items
        expect(app.droplets).to_not include(old_droplet)
      end

      Timecop.travel(Date.today + 3) do
        subject.upload(temp_file_with_content("droplet version 3").path, droplets_to_keep)
        expect(app.reload.droplets).to have(droplets_to_keep).items
        droplet_dest = Tempfile.new("")
        app.current_droplet.download_to(droplet_dest.path)
        expect(droplet_dest.read).to eql("droplet version 3")
      end
    end
  end
end
