require 'spec_helper'
require 'decorators/include_service_plan_space_organization_decorator'

module VCAP::CloudController
  RSpec.describe IncludeServicePlanSpaceOrganizationDecorator do
    describe '.decorate' do
      let(:org1) { Organization.make }
      let(:org2) { Organization.make }

      let(:space1) { Space.make(organization: org1) }
      let(:space2) { Space.make(organization: org2) }

      let!(:space_scoped_plan_1) { generate_space_scoped_plan(space1) }
      let!(:space_scoped_plan_2) { generate_space_scoped_plan(space2) }

      it 'does not add space or orgs for global plan' do
        hash = described_class.decorate({}, [ServicePlan.make(public: true)])
        expect(hash[:included][:spaces]).to be_empty
        expect(hash[:included][:organizations]).to be_empty
      end

      it 'decorates the given hash with spaces and orgs from service plans' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        hash = described_class.decorate(undecorated_hash, [space_scoped_plan_1, space_scoped_plan_2])

        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:monkeys]).to contain_exactly('zach', 'greg')
        expect(hash[:included].keys).to have(3).keys

        expect(hash[:included][:spaces]).to match_array([
          Presenters::V3::SpacePresenter.new(space1).to_hash,
          Presenters::V3::SpacePresenter.new(space2).to_hash
        ])

        expect(hash[:included][:organizations]).to match_array([
          Presenters::V3::OrganizationPresenter.new(org1).to_hash,
          Presenters::V3::OrganizationPresenter.new(org2).to_hash
        ])
      end

      it 'only includes the spaces and orgs from the specified service plans' do
        hash = described_class.decorate({}, [space_scoped_plan_1])
        expect(hash[:included][:spaces]).to have(1).element
        expect(hash[:included][:organizations]).to have(1).element
      end

      context 'when plans share a space' do
        let!(:space_scoped_plan_same_space) { generate_space_scoped_plan(space1) }

        it 'does not duplicate the space' do
          hash = described_class.decorate({}, [space_scoped_plan_1, space_scoped_plan_same_space])
          expect(hash[:included][:spaces]).to have(1).element
        end
      end

      context 'when plans share an org' do
        let(:space3) { Space.make(organization: org2) }
        let!(:space_scoped_plan_same_org) { generate_space_scoped_plan(space3) }

        it 'does not duplicate the org' do
          hash = described_class.decorate({}, [space_scoped_plan_2, space_scoped_plan_same_org])
          expect(hash[:included][:organizations]).to have(1).element
        end
      end
    end

    describe '.match?' do
      it 'matches arrays containing "space.organization"' do
        expect(described_class.match?(['potato', 'space.organization', 'turnip'])).to be_truthy
      end

      it 'does not match other arrays' do
        expect(described_class.match?(['potato', 'turnip'])).to be_falsey
      end
    end
  end

  def generate_space_scoped_plan(space)
    broker = VCAP::CloudController::ServiceBroker.make(space: space)
    offering = VCAP::CloudController::Service.make(service_broker: broker)
    VCAP::CloudController::ServicePlan.make(service: offering)
  end
end
