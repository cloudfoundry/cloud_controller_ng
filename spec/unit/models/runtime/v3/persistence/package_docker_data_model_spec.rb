require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PackageDockerDataModel do
    describe 'associations' do
      let(:package) { PackageModel.make }

      it 'is associated with a package' do
        data = PackageDockerDataModel.new(package: package)
        expect(data.save.reload.package).to eq(package)
      end
    end
  end
end
