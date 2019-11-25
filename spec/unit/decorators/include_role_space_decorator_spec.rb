require 'spec_helper'
require 'decorators/include_role_space_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRoleSpaceDecorator do
    subject(:decorator) { IncludeRoleSpaceDecorator }

    let(:space1) { Space.make(name: 'first-space') }
    let(:space2) { Space.make(name: 'second-space') }
    let(:roles) do
      [
        SpaceManager.make(space: space1),
        SpaceAuditor.make(space: space2)
      ]
    end

    it 'decorates the given hash with spaces from roles' do
      wreathless_hash = { foo: 'bar' }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([
        Presenters::V3::SpacePresenter.new(space1).to_hash,
        Presenters::V3::SpacePresenter.new(space2).to_hash
      ])
    end

    it 'does not overwrite other included fields' do
      wreathless_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([
        Presenters::V3::SpacePresenter.new(space1).to_hash,
        Presenters::V3::SpacePresenter.new(space2).to_hash
      ])
      expect(hash[:included][:monkeys]).to match_array(%w(zach greg))
    end

    describe '.match?' do
      it 'matches include arrays containing "space"' do
        expect(decorator.match?(%w(potato space turnip))).to be_truthy
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(%w(potato turnip))).to be_falsey
      end
    end
  end
end
