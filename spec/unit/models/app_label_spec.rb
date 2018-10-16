require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::AppLabel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      app = AppModel.make(name: 'dora')
      AppLabel.create(app_guid: app.guid, label_key: 'release', label_value: 'stable')
      expect(AppLabel.find(label_key: 'release').label_value).to eq 'stable'
    end
  end
end
