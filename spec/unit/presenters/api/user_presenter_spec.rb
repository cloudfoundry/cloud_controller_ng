require 'spec_helper'

RSpec.describe UserPresenter do
  describe '#to_hash' do
    let(:user) { VCAP::CloudController::User.make(admin: true) }
    subject { UserPresenter.new(user) }

    it 'creates a valid JSON' do
      expect(subject.to_hash).to eq({
        metadata: {
            guid: user.guid,
            created_at: user.created_at.iso8601,
            updated_at: user.updated_at.iso8601,
        },
        entity: {
            admin: true,
            active: false,
            default_space_guid: nil
        }
      })
    end
  end
end
