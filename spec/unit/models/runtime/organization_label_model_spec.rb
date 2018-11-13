require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::OrganizationLabelModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      org = Organization.make(name: 'dora_org')
      OrganizationLabelModel.create(resource_guid: org.guid, key_name: 'release', value: 'stable')
      expect(OrganizationLabelModel.find(key_name: 'release').value).to eq 'stable'
    end
  end
end
