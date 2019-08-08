require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IncludeSpaceDecorator do
    subject(:decorator) { IncludeSpaceDecorator }
    let(:space1) { Space.make(name: 'first-space') }
    let(:space2) { Space.make(name: 'second-space') }
    let(:apps) { [AppModel.make(space: space1), AppModel.make(space: space2), AppModel.make(space: space1)] }

    it 'decorates the given hash with spaces from apps' do
      undecorated_hash = { foo: 'bar' }
      hash = subject.decorate(undecorated_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash])
    end

    it 'does not overwrite other included fields' do
      undecorated_hash = { foo: 'bar', included: { monkeys: ['zach', 'greg'] } }
      hash = subject.decorate(undecorated_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash])
      expect(hash[:included][:monkeys]).to match_array(['zach', 'greg'])
    end

    describe '.match?' do
      it 'matches include arrays containing "space"' do
        expect(decorator.match?(['potato', 'space', 'turnip'])).to be_truthy
      end

      it 'matches include arrays containing "space.organization"' do
        expect(decorator.match?(['potato', 'space.organization', 'turnip'])).to be_truthy
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(['potato', 'turnip'])).to be_falsey
      end
    end
  end
end
