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
        expect(package.labels.map { |label| { key: label.key_name, value: label.value } }).to match_array([{ key: 'freaky', value: 'wednesday' }])
        expect(package.annotations.map { |a| { key: a.key, value: a.value } }).
          to match_array([{ key: 'tokyo', value: 'grapes' }])
      end
    end
  end
end
