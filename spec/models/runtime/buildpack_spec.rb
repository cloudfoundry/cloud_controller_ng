require "spec_helper"

module VCAP::CloudController
  describe Buildpack, type: :model do
    describe "validations" do
      it "enforces unique names" do
       Buildpack.create(:name => "my_custom_buildpack", :key => "xyz", :priority => 0)

        expect {
          Buildpack.create(:name => "my_custom_buildpack", :key => "xxxx", :priority =>0)
        }.to raise_error(Sequel::ValidationFailed, /name unique/)
      end
    end

    describe "listing admin buildpacks" do
      let(:blobstore) { double :buildpack_blobstore }

      let(:buildpack_file_1) { Tempfile.new("admin buildpack 1") }
      let(:buildpack_file_2) { Tempfile.new("admin buildpack 2") }
      let(:buildpack_file_3) { Tempfile.new("admin buildpack 3") }

      let(:buildpack_blobstore) { CloudController::DependencyLocator.instance.buildpack_blobstore }
      let(:url_generator) { CloudController::DependencyLocator.instance.blobstore_url_generator }

      before do
        Timecop.freeze # The expiration time of the blobstore uri
        Buildpack.dataset.delete

        buildpack_blobstore.cp_to_blobstore(buildpack_file_1.path, "a key")
        Buildpack.make(key: "a key", priority: 2)

        buildpack_blobstore.cp_to_blobstore(buildpack_file_2.path, "b key")
        Buildpack.make(key: "b key", priority: 1)

        buildpack_blobstore.cp_to_blobstore(buildpack_file_3.path, "c key")
        @another_buildpack = Buildpack.make(key: "c key", priority: 3)
      end

      subject(:all_buildpacks) { Buildpack.list_admin_buildpacks(url_generator) }

      it { should have(3).items }
      it { should include(url: buildpack_blobstore.download_uri("a key"), key: "a key") }
      it { should include(url: buildpack_blobstore.download_uri("b key"), key: "b key") }
      it { should include(url: buildpack_blobstore.download_uri("c key"), key: "c key") }

      it "returns the list in priority order" do
        expect(all_buildpacks.map { |b| b[:key] }).to eq ["b key", "a key", "c key"]
      end

      it "doesn't list any buildpacks with null keys" do
        @another_buildpack.key = nil
        @another_buildpack.save

        expect(all_buildpacks).to_not include(@another_buildpack)
        expect(all_buildpacks).to have(2).items
      end

      it "randomly orders any buildpacks with the same priority (for now we did not want to make clever logic of moving stuff around: up to the user to get it all correct)" do
        @another_buildpack.priority = 1
        @another_buildpack.save

        expect(all_buildpacks[2][:key]).to eq("a key")
      end

      context "when there are buildpacks with null keys" do
        let!(:null_buildpack) { Buildpack.create(:name => "nil_key_custom_buildpack", :priority => 0) }

        it "only returns buildpacks with non-null keys" do
          expect(Buildpack.all).to include(null_buildpack)
          expect(all_buildpacks).to_not include(null_buildpack)
          expect(all_buildpacks).to have(3).items
        end
      end

      context "when there are buildpacks with empty keys" do
        let!(:empty_buildpack) { Buildpack.create(:name => "nil_key_custom_buildpack", :key => "", :priority => 0) }

        it "only returns buildpacks with non-null keys" do
          expect(Buildpack.all).to include(empty_buildpack)
          expect(all_buildpacks).to_not include(empty_buildpack)
          expect(all_buildpacks).to have(3).items
        end
      end
    end

    describe "staging_message" do
      it "contains the buildpack key" do
        buildpack = Buildpack.make
        expect(buildpack.staging_message).to eql(buildpack_key: buildpack.key)
      end
    end
  end
end
