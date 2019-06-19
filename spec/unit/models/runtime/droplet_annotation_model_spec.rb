require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::DropletAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      droplet = DropletModel.make
      DropletAnnotationModel.create(resource_guid: droplet.guid, key_prefix: 'coolapp', key: 'release', value: 'stable')
      expect(DropletAnnotationModel.find(key_prefix: 'coolapp', key: 'release').value).to eq 'stable'
    end
  end
end
