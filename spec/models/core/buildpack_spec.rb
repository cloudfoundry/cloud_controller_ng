require "spec_helper"

module VCAP::CloudController
  describe Buildpack, type: :model do
    describe "validations" do
      it "enforces unique names" do
       Buildpack.create(:name => "my custom buildpack", :key => "xyz", :priority => 0)

        expect {
          Buildpack.create(:name => "my custom buildpack", :key => "xxxx", :priority =>0)
        }.to raise_error(Sequel::ValidationFailed, /name unique/)
      end
    end

    describe "listing admin buildpacks" do
      let(:blobstore) {  CloudController::DependencyLocator.instance.buildpack_blobstore }

      before do
        Buildpack.dataset.delete
        @buildpack = Buildpack.make()
        @another_buildpack = Buildpack.make()
      end

      it "returns a list of names and urls" do
        download_url = "http://example.com/buildpacks/1"
        blobstore.should_receive(:download_uri).with(@buildpack.key).and_return(download_url)
        blobstore.should_receive(:download_uri).with(@another_buildpack.key).and_return(download_url)

        list = Buildpack.list_admin_buildpacks
        expect(list).to have(2).items
        expect(list).to include(url: download_url, key: @buildpack.key)
      end
    end
  end
end
