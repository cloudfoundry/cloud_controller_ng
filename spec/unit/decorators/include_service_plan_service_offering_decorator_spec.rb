require 'spec_helper'
require 'decorators/include_service_plan_service_offering_decorator'

module VCAP::CloudController
  RSpec.describe IncludeServicePlanServiceOfferingDecorator do
    describe '.decorate' do
      let(:offering_1) { Service.make }
      let(:offering_2) { Service.make }
      let(:plan_1) { ServicePlan.make(service: offering_1) }
      let(:plan_2) { ServicePlan.make(service: offering_2) }
      let(:plan_3) { ServicePlan.make(service: offering_2) }

      it 'decorates the given hash with service offerings from service plans' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        hash = described_class.decorate(undecorated_hash, [plan_1, plan_2, plan_3])

        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:monkeys]).to contain_exactly('zach', 'greg')
        expect(hash[:included].keys).to have(2).keys

        expect(hash[:included][:service_offerings]).to match_array([
          Presenters::V3::ServiceOfferingPresenter.new(offering_1).to_hash,
          Presenters::V3::ServiceOfferingPresenter.new(offering_2).to_hash
        ])
      end

      it 'only includes the service offerings from the specified service plans' do
        hash = described_class.decorate({}, [plan_1])
        expect(hash[:included][:service_offerings]).to have(1).element
      end
    end

    describe '.match?' do
      it 'matches arrays containing "service_offering"' do
        expect(described_class.match?(['potato', 'service_offering', 'turnip'])).to be_truthy
      end

      it 'does not match other arrays' do
        expect(described_class.match?(['potato', 'turnip'])).to be_falsey
      end
    end
  end
end
