require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::SpaceLabelModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      space = create(:space, name: 'dora_space')
      create(:space_label_model, resource_guid: space.guid, key_name: 'release', value: 'stable')
      expect(SpaceLabelModel.find(key_name: 'release').value).to eq 'stable'
    end
  end
end
