require 'spec_helper'
require 'date'

module VCAP::CloudController
  RSpec.describe SpaceSupporter, type: :model do
    let(:space) { Space.make }
    let(:user) { User.make }

    describe 'Validations' do
      it { is_expected.to validate_uniqueness [:space_id, :user_id] }
      it { is_expected.to validate_presence :space_id }
      it { is_expected.to validate_presence :user_id }

      it { is_expected.to have_timestamp_columns }
    end

    it 'can be created' do
      SpaceSupporter.create(space: space, user: user)
      app_supporter = SpaceSupporter.find(space_id: space.id, user_id: user.id)

      expect(app_supporter.guid).to be_a_guid
    end

    it_should_be_removed(by: '2022/01/08', explanation: 'Timebox failure: spaces_application_supporters table is no longer being used. Consider removing it.')
  end
end
