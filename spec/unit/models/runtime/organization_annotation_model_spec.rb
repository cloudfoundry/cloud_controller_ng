require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::OrganizationAnnotationModel, type: :model do
    it { is_expected.to have_timestamp_columns }

    it 'can be created' do
      org = FactoryBot.create(:organization, name: 'zrob-org')
      OrganizationAnnotationModel.create(resource_guid: org.guid, key: 'state', value: 'Ohio')
      expect(OrganizationAnnotationModel.find(key: 'state').value).to eq 'Ohio'
    end
  end
end
