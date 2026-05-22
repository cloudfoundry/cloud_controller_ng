require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::OrganizationAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      org = create(:organization, name: 'zrob-org')
      create(:organization_annotation_model, resource_guid: org.guid, key_prefix: 'us', key_name: 'state', value: 'Ohio')
      expect(OrganizationAnnotationModel.find(resource_guid: org.guid, key_prefix: 'us', key_name: 'state').value).to eq 'Ohio'
    end
  end
end
