require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::UserLabelModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      user = User.make(guid: 'dora')
      UserLabelModel.create(resource_guid: user.guid, key_name: 'release', value: 'stable')
      expect(UserLabelModel.find(key_name: 'release').value).to eq 'stable'
    end
  end
end
