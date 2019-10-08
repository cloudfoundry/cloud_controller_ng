require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceManager, type: :model do
    let(:space) { Space.make }
    let(:user) { User.make }

    describe 'Validations' do
      it { is_expected.to validate_uniqueness [:space_id, :user_id] }
      it { is_expected.to validate_presence :space_id }
      it { is_expected.to validate_presence :user_id }

      it { is_expected.to have_timestamp_columns }
    end

    it 'can be created' do
      SpaceManager.create(space_id: space.id, user_id: user.id)

      space_manager_found = SpaceManager.find(space_id: space.id, user_id: user.id)

      expect(space_manager_found.guid).to be_a_guid
      expect(space_manager_found.created_at).to be_a Time
      expect(space_manager_found.updated_at).to be_a Time
      expect(space_manager_found.type).to eq(RoleTypes::SPACE_MANAGER)
      expect(space_manager_found.space_id).to eq space.id
      expect(space_manager_found.user_id).to eq user.id
    end

    it 'can be used to retrieve user guid' do
      SpaceManager.create(space_id: space.id, user_id: user.id)
      space_manager_found = SpaceManager.find(space_id: space.id, user_id: user.id)

      expect(space_manager_found.user).to eq user
    end
  end
end
