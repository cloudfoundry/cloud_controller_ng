require "spec_helper"

module VCAP::CloudController
  describe Models::Buildpack, type: :model do
    describe "validations" do
      it "enforces unique names" do
       Models::Buildpack.create(:name => "my custom buildpack", :key => "xyz", :priority => 0)

        expect {
          Models::Buildpack.create(:name => "my custom buildpack", :key => "xxxx", :priority =>0)
        }.to raise_error(Sequel::ValidationFailed, /name unique/)
      end
    end
  end
end
