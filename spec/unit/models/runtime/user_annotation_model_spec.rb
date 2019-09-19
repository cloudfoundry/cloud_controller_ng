require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::UserAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      user = User.make(guid: 'dora')
      UserAnnotationModel.create(resource_guid: user.guid, key_prefix: 'something', key_name: 'release', value: 'stable')
      expect(UserAnnotationModel.find(key_prefix: 'something', key: 'release').value).to eq 'stable'
    end
  end
end
