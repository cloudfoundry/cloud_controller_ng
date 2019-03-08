require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::AppAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      app = FactoryBot.create(:app, name: 'dora')
      AppAnnotationModel.create(resource_guid: app.guid, key: 'release', value: 'stable')
      expect(AppAnnotationModel.find(key: 'release').value).to eq 'stable'
    end
  end
end
