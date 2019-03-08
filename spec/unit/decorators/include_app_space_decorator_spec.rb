require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IncludeAppSpaceDecorator do
    subject(:decorator) { IncludeAppSpaceDecorator }
    let(:space1) { FactoryBot.create(:space, name: 'first-space') }
    let(:space2) { FactoryBot.create(:space, name: 'second-space') }
    let(:apps) do
      [
        FactoryBot.create(:app, space: space1),
        FactoryBot.create(:app, space: space2),
        FactoryBot.create(:app, space: space1)
      ]
    end

    it 'decorates the given hash with spaces from apps' do
      wreathless_hash = { foo: 'bar' }
      hash = subject.decorate(wreathless_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash])
    end

    it 'does not overwrite other included fields' do
      wreathless_hash = { foo: 'bar', included: { monkeys: ['zach', 'greg'] } }
      hash = subject.decorate(wreathless_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash])
      expect(hash[:included][:monkeys]).to match_array(['zach', 'greg'])
    end
  end
end
