require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::DropletLabelModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      droplet = DropletModel.make
      DropletLabelModel.create(resource_guid: droplet.guid, key_name: 'release', value: 'stable')
      expect(DropletLabelModel.find(key_name: 'release').value).to eq 'stable'
    end
  end
end
