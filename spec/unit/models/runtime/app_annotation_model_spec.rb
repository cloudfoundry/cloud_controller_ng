require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::AppAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      app = create(:app_model, name: 'dora')
      create(:app_annotation_model, resource_guid: app.guid, key_prefix: 'something', key_name: 'release', value: 'stable')
      expect(AppAnnotationModel.find(key_prefix: 'something', key_name: 'release').value).to eq 'stable'
    end
  end
end
