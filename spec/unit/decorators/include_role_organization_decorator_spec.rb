require 'spec_helper'
require 'decorators/include_role_organization_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRoleOrganizationDecorator do
    subject(:decorator) { IncludeRoleOrganizationDecorator }

    let(:organization1) { Organization.make(name: 'first-organization') }
    let(:organization2) { Organization.make(name: 'second-organization') }
    let(:orguser) { OrganizationUser.make(organization: organization1) }
    let(:orgauditor) { OrganizationAuditor.make(organization: organization2) }
    let(:roles) do
      [
        Role.where(user_id: orguser.user_id, organization_id: organization1.id).first,
        Role.where(user_id: orgauditor.user_id, organization_id: organization2.id).first
      ]
    end

    it 'decorates the given hash with organizations from roles' do
      wreathless_hash = { foo: 'bar' }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:organizations]).to match_array([
        Presenters::V3::OrganizationPresenter.new(organization1).to_hash,
        Presenters::V3::OrganizationPresenter.new(organization2).to_hash
      ])
    end

    it 'does not overwrite other included fields' do
      wreathless_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:organizations]).to match_array([
        Presenters::V3::OrganizationPresenter.new(organization1).to_hash,
        Presenters::V3::OrganizationPresenter.new(organization2).to_hash
      ])
      expect(hash[:included][:monkeys]).to match_array(%w(zach greg))
    end

    describe '.match?' do
      it 'matches include arrays containing "organization"' do
        expect(decorator.match?(%w(potato organization turnip))).to be_truthy
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(%w(potato turnip))).to be_falsey
      end
    end
  end
end
