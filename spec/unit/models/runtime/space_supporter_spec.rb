require 'spec_helper'
require 'date'

module VCAP::CloudController
  RSpec.describe SpaceSupporter, type: :model do
    let(:space) { create(:space) }
    let(:user) { create(:user) }

    describe 'uniqueness' do
      it 'prevents duplicate space_id and user_id combination' do
        SpaceSupporter.create(space_id: space.id, user_id: user.id)
        expect do
          SpaceSupporter.create(space_id: space.id, user_id: user.id)
        end.to raise_error(Sequel::ValidationFailed, /unique/)
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :space_id }
      it { is_expected.to validate_presence :user_id }

      it { is_expected.to have_timestamp_columns }
    end

    it 'can be created' do
      SpaceSupporter.create(space:, user:)
      app_supporter = SpaceSupporter.find(space_id: space.id, user_id: user.id)

      expect(app_supporter.guid).to be_a_guid
    end
  end
end
