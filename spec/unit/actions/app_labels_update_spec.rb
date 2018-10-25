require 'spec_helper'
require 'actions/app_labels_update'

module VCAP::CloudController
  RSpec.describe AppLabelsUpdate do
    subject(:result) { AppLabelsUpdate.update(app, labels) }

    let(:app) { AppModel.make }
    let(:labels) do
      {
          release: 'stable',
          'joyofcooking.com/potato': 'mashed'
      }
    end

    it 'updates the labels' do
      subject
      expect(AppLabelModel.find(app_guid: app.guid, key_name: 'release').value).to eq 'stable'
      expect(AppLabelModel.find(app_guid: app.guid, key_prefix: 'joyofcooking.com', key_name: 'potato').value).to eq 'mashed'
    end

    context 'no labels' do
      let(:labels) { nil }

      it 'does not change any labels' do
        expect do
          subject
        end.not_to change { AppLabelModel.count }
      end
    end

    context 'when existing labels are being modified' do
      let(:labels) do
        {
            release: 'stable',
            'joyofcooking.com/potato': 'mashed'
        }
      end

      let!(:old_label) do
        AppLabelModel.create(app_guid: app.guid, key_name: 'release', value: 'unstable')
      end
      let!(:old_label_with_prefix) do
        AppLabelModel.create(app_guid: app.guid, key_prefix: 'joyofcooking.com', key_name: 'potato', value: 'fried')
      end

      it 'updates the old label' do
        subject
        expect(old_label.reload.value).to eq 'stable'
        expect(old_label_with_prefix.reload.value).to eq 'mashed'
      end
    end
  end
end
