require 'spec_helper'
require 'decorators/include_role_organization_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRoleOrganizationDecorator do
    subject(:decorator) { IncludeRoleOrganizationDecorator }

    let(:organization1) { Organization.make(name: 'first-organization') }
    let(:organization2) { Organization.make(name: 'second-organization') }
    let(:org_user) { OrganizationUser.make(organization: organization1) }
    let(:org_auditor) { OrganizationAuditor.make(organization: organization2) }
    let(:space_manager) { SpaceManager.make }
    # roles is an array of VCAP::CloudController::Role objects
    let(:roles) { Role.where(guid: [org_user, org_auditor, space_manager].map(&:guid)).all }

    it 'decorates the given hash with organizations from roles' do
      wreathless_hash = { foo: 'bar' }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:organizations]).to contain_exactly(Presenters::V3::OrganizationPresenter.new(organization1).to_hash,
                                                                 Presenters::V3::OrganizationPresenter.new(organization2).to_hash)
    end

    it 'does not overwrite other included fields' do
      wreathless_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:organizations]).to contain_exactly(Presenters::V3::OrganizationPresenter.new(organization1).to_hash,
                                                                 Presenters::V3::OrganizationPresenter.new(organization2).to_hash)
      expect(hash[:included][:monkeys]).to match_array(%w[zach greg])
    end

    context 'only space roles' do
      let!(:roles) { Role.where(guid: space_manager.guid).all }

      it 'does not query the database' do
        expect do
          subject.decorate({}, roles)
        end.to have_queried_db_times(/select \* from .organizations. where/i, 0)
      end
    end

    describe '.match?' do
      it 'matches include arrays containing "organization"' do
        expect(decorator.match?(%w[potato organization turnip])).to be(true)
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(%w[potato turnip])).not_to be(true)
      end
    end
  end
end
