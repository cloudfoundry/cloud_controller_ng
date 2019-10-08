require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceAuditor, type: :model do
    let(:space) { Space.make }
    let(:user) { User.make }

    describe 'Validations' do
      it { is_expected.to validate_uniqueness [:space_id, :user_id] }
      it { is_expected.to validate_presence :space_id }
      it { is_expected.to validate_presence :user_id }

      it { is_expected.to have_timestamp_columns }
    end

    it 'can be created' do
      SpaceAuditor.create(space_id: space.id, user_id: user.id)

      space_auditor_found = SpaceAuditor.find(space_id: space.id, user_id: user.id)

      expect(space_auditor_found.guid).to be_a_guid
      expect(space_auditor_found.created_at).to be_a Time
      expect(space_auditor_found.updated_at).to be_a Time
      expect(space_auditor_found.type).to eq(RoleTypes::SPACE_AUDITOR)
      expect(space_auditor_found.space_id).to eq space.id
      expect(space_auditor_found.user_id).to eq user.id
    end

    it 'can be used to retrieve user guid' do
      SpaceAuditor.create(space_id: space.id, user_id: user.id)
      space_auditor_found = SpaceAuditor.find(space_id: space.id, user_id: user.id)

      expect(space_auditor_found.user).to eq user
    end
  end
end
