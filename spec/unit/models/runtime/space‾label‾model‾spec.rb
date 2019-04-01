require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::SpaceLabelModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      space = Space.make(name: 'dora_space')
      SpaceLabelModel.create(resource_guid: space.guid, key_name: 'release', value: 'stable')
      expect(SpaceLabelModel.find(key_name: 'release').value).to eq 'stable'
    end
  end
end
