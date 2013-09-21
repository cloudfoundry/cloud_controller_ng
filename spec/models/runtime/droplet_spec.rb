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
    before do
      blobstore.cp_from_local(tmp_file.path, "#{app.guid}/droplet_hash")
      blobstore.cp_from_local(tmp_file.path, "#{app.guid}")
    end

    it "removes the new and old format keys (guid/sha, guid)" do
      expect { subject.delete }.to change {
        [ blobstore.exists?("#{app.guid}/droplet_hash"),
          blobstore.exists?("#{app.guid}"),
        ]
      }.from([true, true]).to([false, false])
    end
  end

  describe "#exists?" do
    context "when the app does not have a droplet hash" do
      before { app.droplet_hash = nil }

      it { should_not exist }
    end

    context "when the new format key exists" do
      before do
        blobstore.cp_from_local(tmp_file.path, "#{app.guid}/droplet_hash")
      end

      it { should exist }
    end

    context "when the old format key exists" do
      before do
        blobstore.cp_from_local(tmp_file.path, app.guid)
      end

      it { should exist }
    end

    context "when neither keys exist" do
      it { should_not exist }
    end
  end
end