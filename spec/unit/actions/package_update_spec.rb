require 'spec_helper'
require 'actions/package_update'

module VCAP::CloudController
  RSpec.describe PackageUpdate do
    subject(:package_update) { PackageUpdate.new }

    describe '#update' do
      let(:body) do
        {
          metadata: {
            labels: {
              freaky: 'wednesday',
            },
            annotations: {
              tokyo: 'grapes'
            },
          },
        }
      end
      let(:package) { PackageModel.make }
      let(:message) { PackageUpdateMessage.new(body) }

      it 'updates the package metadata' do
        expect(message).to be_valid
        package_update.update(package, message)

        package.reload
        expect(package).to have_labels({ key: 'freaky', value: 'wednesday' })
        expect(package).to have_annotations({ key: 'tokyo', value: 'grapes' })
      end
    end
  end
end
