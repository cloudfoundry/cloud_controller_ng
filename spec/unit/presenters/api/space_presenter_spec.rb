require 'spec_helper'

RSpec.describe SpacePresenter do
  describe '#to_hash' do
    let(:space) { VCAP::CloudController::Space.make }
    subject { SpacePresenter.new(space) }

    it 'creates a valid JSON' do
      expect(subject.to_hash).to eq({
        metadata: {
          guid: space.guid,
          created_at: space.created_at.iso8601,
          updated_at: space.updated_at.iso8601,
        },
        entity: {
          name: space.name
        }
      })
    end
  end
end
