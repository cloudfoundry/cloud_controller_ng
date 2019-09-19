require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IncludeSpaceOrganizationDecorator do
    subject(:decorator) { IncludeSpaceOrganizationDecorator }
    let(:organization1) { Organization.make(name: 'first-organization') }
    let(:organization2) { Organization.make(name: 'second-organization') }
    let(:space1) { Space.make(name: 'first-space', organization: organization1) }
    let(:space2) { Space.make(name: 'second-space', organization: organization2) }
    let(:spaces) { [space1, space2] }

    it 'decorates the given hash with organizations from spaces' do
      undecorated_hash = { foo: 'bar' }
      hash = subject.decorate(undecorated_hash, spaces)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:organizations]).to match_array([
        Presenters::V3::OrganizationPresenter.new(organization1).to_hash,
        Presenters::V3::OrganizationPresenter.new(organization2).to_hash
      ])
    end

    it 'does not overwrite other included fields' do
      undecorated_hash = { foo: 'bar', included: { monkeys: ['zach', 'greg'] } }
      hash = subject.decorate(undecorated_hash, spaces)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:organizations]).to match_array([
        Presenters::V3::OrganizationPresenter.new(organization1).to_hash,
        Presenters::V3::OrganizationPresenter.new(organization2).to_hash
      ])
      expect(hash[:included][:monkeys]).to match_array(['zach', 'greg'])
    end

    describe '.match?' do
      it 'matches include arrays containing "org"' do
        expect(decorator.match?(['potato', 'org', 'turnip'])).to be_truthy
      end

      it 'matches include arrays containing "organization"' do
        expect(decorator.match?(['potato', 'organization', 'turnip'])).to be_truthy
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(['potato', 'turnip'])).to be_falsey
      end
    end
  end
end
