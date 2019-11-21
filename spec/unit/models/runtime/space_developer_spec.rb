require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceDeveloper, type: :model do
    let(:space) { Space.make }
    let(:user) { User.make }

    describe 'Validations' do
      it { is_expected.to validate_uniqueness [:space_id, :user_id] }
      it { is_expected.to validate_presence :space_id }
      it { is_expected.to validate_presence :user_id }

      it { is_expected.to have_timestamp_columns }
    end

    it 'can be created' do
      SpaceDeveloper.create(space_id: space.id, user_id: user.id)

      space_developer_found = SpaceDeveloper.find(space_id: space.id, user_id: user.id)

      expect(space_developer_found.guid).to be_a_guid
      expect(space_developer_found.created_at).to be_a Time
      expect(space_developer_found.updated_at).to be_a Time
      expect(space_developer_found.type).to eq(RoleTypes::SPACE_DEVELOPER)
      expect(space_developer_found.space_id).to eq space.id
      expect(space_developer_found.user_id).to eq user.id
    end

    it 'can be used to retrieve user guid' do
      SpaceDeveloper.create(space_id: space.id, user_id: user.id)
      space_developer_found = SpaceDeveloper.find(space_id: space.id, user_id: user.id)

      expect(space_developer_found.user).to eq user
    end
  end
end
