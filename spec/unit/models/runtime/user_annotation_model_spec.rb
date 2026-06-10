require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::UserAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      user = create(:user, guid: 'dora')
      create(:user_annotation_model, resource_guid: user.guid, key_prefix: 'something', key_name: 'release', value: 'stable')
      expect(UserAnnotationModel.find(key_prefix: 'something', key_name: 'release').value).to eq 'stable'
    end
  end
end
