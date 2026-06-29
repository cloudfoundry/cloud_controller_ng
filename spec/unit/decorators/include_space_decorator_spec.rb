require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IncludeSpaceDecorator do
    subject(:decorator) { IncludeSpaceDecorator }
    let(:space1) { create(:space, name: 'first-space', created_at: Time.now.utc - 1.second) }
    let(:space2) { create(:space, name: 'second-space') }
    let(:apps) { [create(:app_model, space: space1), create(:app_model, space: space2), create(:app_model, space: space1)] }

    before do
      allow(Permissions).to receive(:new).and_return(double(can_read_globally?: true))
    end

    it 'decorates the given hash with spaces from apps in the correct order' do
      undecorated_hash = { foo: 'bar' }
      hash = subject.decorate(undecorated_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to eq([Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash])
    end

    it 'does not overwrite other included fields' do
      undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
      hash = subject.decorate(undecorated_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to contain_exactly(Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash)
      expect(hash[:included][:monkeys]).to match_array(%w[zach greg])
    end

    describe '.match?' do
      it 'matches include arrays containing "space"' do
        expect(decorator.match?(%w[potato space turnip])).to be(true)
      end

      it 'matches include arrays containing "space.organization"' do
        expect(decorator.match?(%w[potato space.organization turnip])).to be(true)
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(%w[potato turnip])).not_to be(true)
      end
    end
  end
end
