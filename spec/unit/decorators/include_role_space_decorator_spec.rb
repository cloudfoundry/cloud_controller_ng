require 'spec_helper'
require 'decorators/include_role_space_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRoleSpaceDecorator do
    subject(:decorator) { IncludeRoleSpaceDecorator }

    let(:space1) { Space.make(name: 'first-space', created_at: Time.now.utc - 1.second) }
    let(:space2) { Space.make(name: 'second-space') }

    let(:space_manager) { SpaceManager.make(space: space1) }
    let(:space_auditor) { SpaceAuditor.make(space: space2) }
    let(:org_manager) { OrganizationManager.make }

    # roles is an array of VCAP::CloudController::Role objects
    let(:roles) { Role.where(guid: [space_manager, space_auditor, org_manager].map(&:guid)).all }

    it 'decorates the given hash with spaces from roles in the correct order' do
      wreathless_hash = { foo: 'bar' }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to eq([Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash])
    end

    it 'does not overwrite other included fields' do
      wreathless_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
      hash = subject.decorate(wreathless_hash, roles)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to contain_exactly(Presenters::V3::SpacePresenter.new(space1).to_hash, Presenters::V3::SpacePresenter.new(space2).to_hash)
      expect(hash[:included][:monkeys]).to match_array(%w[zach greg])
    end

    context 'only org roles' do
      let(:roles) { Role.where(guid: org_manager.guid).all }

      it 'does not query the database' do
        expect do
          subject.decorate({}, roles)
        end.to have_queried_db_times(/select \* from .spaces. where/i, 0)
      end
    end

    describe '.match?' do
      it 'matches include arrays containing "space"' do
        expect(decorator.match?(%w[potato space turnip])).to be(true)
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(%w[potato turnip])).not_to be(true)
      end
    end
  end
end
