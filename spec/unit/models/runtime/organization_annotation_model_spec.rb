require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::OrganizationAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      org = Organization.make(name: 'zrob-org')
      OrganizationAnnotationModel.create(resource_guid: org.guid, key_prefix: 'us', key: 'state', value: 'Ohio')
      expect(OrganizationAnnotationModel.find(key_prefix: 'us', key: 'state').value).to eq 'Ohio'
    end
  end
end
