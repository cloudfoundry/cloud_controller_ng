require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::AppLabelModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      app = AppModel.make(name: 'dora')
      AppLabelModel.create(resource_guid: app.guid, key_name: 'release', value: 'stable')
      expect(AppLabelModel.find(key_name: 'release').value).to eq 'stable'
    end
  end
end
