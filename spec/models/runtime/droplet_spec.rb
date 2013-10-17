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

    describe "#delete_from_blobstore" do
      subject(:droplet) do
        Droplet.new(app: app, droplet_hash: "droplet_hash")
      end

      context "with only one droplet associated with the app" do
        # working around a problem with local blob stores where the old format
        # key is also the parent directory, and trying to delete it when there are
        # multiple versions of the app results in an "is a directory" error
        it "it hides EISDIR if raised by the blob store on deleting the old format of the droplet key" do
          blobstore.should_receive(:delete).with("#{app.guid}/droplet_hash")
          blobstore.should_receive(:delete).with("#{app.guid}").and_raise Errno::EISDIR
          expect { subject.delete_from_blobstore }.to_not raise_error
        end

        it "it doesnt hide EISDIR if raised for the new droplet key format" do
          blobstore.should_receive(:delete).with("#{app.guid}/droplet_hash").and_raise Errno::EISDIR
          expect { subject.delete_from_blobstore }.to raise_error
        end

        it "removes the new and old format keys (guid/sha, guid)" do
          blobstore.cp_to_blobstore(tmp_file_with_content.path, "#{app.guid}/droplet_hash")
          blobstore.cp_to_blobstore(tmp_file_with_content.path, "#{app.guid}")
          expect { subject.delete_from_blobstore }.to change {
            [ blobstore.exists?("#{app.guid}/droplet_hash"),
              blobstore.exists?("#{app.guid}"),
            ]
          }.from([true, true]).to([false, false])
        end
      end

      context "with multiple droplets associated with the app" do
        before do
          blobstore.cp_to_blobstore(tmp_file_with_content.path, "#{app.guid}/another_droplet_hash")
          blobstore.cp_to_blobstore(tmp_file_with_content.path, "#{app.guid}/droplet_hash")
          blobstore.cp_to_blobstore(tmp_file_with_content.path, "#{app.guid}")
        end

        it "doesn't raise an error" do
          expect { subject.delete_from_blobstore }.to_not raise_error
        end
      end
    end

    context "when deleting droplets" do
      it "destroy drives delete_from_blobstore" do
        app = AppFactory.make
        droplet = app.current_droplet
        droplet.should_receive(:delete_from_blobstore)
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
  end
end