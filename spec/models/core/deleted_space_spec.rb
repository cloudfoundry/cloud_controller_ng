require "spec_helper"

module VCAP::CloudController
  describe DeletedSpace do
    subject(:deleted_space) { DeletedSpace.new }

    its(:guid) { should eq "" }

    it "has a fake organization with an empty guid" do
      expect(deleted_space.organization.guid).to eq ""
    end
  end
end