require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceApplicationSupporter, type: :model do
    let(:space) { Space.make }
    let(:user) { User.make }

    describe 'Validations' do
      it { is_expected.to validate_uniqueness [:space_id, :user_id] }
      it { is_expected.to validate_presence :space_id }
      it { is_expected.to validate_presence :user_id }

      it { is_expected.to have_timestamp_columns }
    end

    it 'can be created' do
      SpaceApplicationSupporter.create(space: space, user: user)
      app_supporter = SpaceApplicationSupporter.find(space_id: space.id, user_id: user.id)

      expect(app_supporter.guid).to be_a_guid
    end
  end
end
