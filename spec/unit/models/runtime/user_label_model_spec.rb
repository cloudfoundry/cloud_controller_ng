require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::UserLabelModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      user = create(:user, guid: 'dora')
      create(:user_label_model, resource_guid: user.guid, key_name: 'release', value: 'stable')
      expect(UserLabelModel.find(key_name: 'release').value).to eq 'stable'
    end
  end
end
