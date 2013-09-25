require "spec_helper"

describe CloudController::Droplet do
  let(:app) do
    VCAP::CloudController::App.make(
      droplet_hash: "droplet_hash")
  end

  let(:blobstore) do
    Blobstore.new(
      {
        provider: "AWS",
        aws_access_key_id: 'fake_access_key_id',
        aws_secret_access_key: 'fake_secret_access_key',
      }, "directory_key")
  end

  let(:tmp_file) do
    Tempfile.new("a file")
  end

  subject { described_class.new(app, blobstore) }

  describe "#save" do
    it "life cycle" do
      expect { subject.save(tmp_file.path) }.to change {
        subject.exists?
      }.from(false).to(true)
    end
  end

  describe "#delete" do
    context "with only one droplet associated with the app" do
      before do
        blobstore.cp_to_blobstore(tmp_file.path, "#{app.guid}/droplet_hash")
        blobstore.cp_to_blobstore(tmp_file.path, "#{app.guid}")
      end

      # working around a problem with local blob stores where the old format
      # key is also the parent directory, and trying to delete it when there are
      # multiple versions of the app results in an "is a directory" error
      it "it hides EISDIR if raised by the blob store on deleting the old format of the droplet key" do
        blobstore.should_receive(:delete).with("#{app.guid}/droplet_hash")
        blobstore.should_receive(:delete).with("#{app.guid}").and_raise Errno::EISDIR
        expect { subject.delete }.to_not raise_error
      end

      it "it doesnt hide EISDIR if raised for the new droplet key format" do
        blobstore.should_receive(:delete).with("#{app.guid}/droplet_hash").and_raise Errno::EISDIR
        expect { subject.delete }.to raise_error
      end

      it "removes the new and old format keys (guid/sha, guid)" do
        expect { subject.delete }.to change {
          [ blobstore.exists?("#{app.guid}/droplet_hash"),
            blobstore.exists?("#{app.guid}"),
        ]
        }.from([true, true]).to([false, false])
      end
    end

    context "with multiple droplets associated with the app" do
      before do
        blobstore.cp_to_blobstore(tmp_file.path, "#{app.guid}/another_droplet_hash")
        blobstore.cp_to_blobstore(tmp_file.path, "#{app.guid}/droplet_hash")
        blobstore.cp_to_blobstore(tmp_file.path, "#{app.guid}")
      end

      it "doesn't raise an error" do
        expect { subject.delete }.to_not raise_error
      end
    end

  end

  describe "#exists?" do
    context "when the app does not have a droplet hash" do
      before { app.droplet_hash = nil }

      it { should_not exist }
    end

    context "when the new format key exists" do
      before do
        blobstore.cp_to_blobstore(tmp_file.path, "#{app.guid}/droplet_hash")
      end

      it { should exist }
    end

    context "when the old format key exists" do
      before do
        blobstore.cp_to_blobstore(tmp_file.path, app.guid)
      end

      it { should exist }
    end

    context "when neither keys exist" do
      it { should_not exist }
    end
  end
end
