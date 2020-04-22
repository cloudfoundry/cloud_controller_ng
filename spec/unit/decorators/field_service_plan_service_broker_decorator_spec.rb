require 'spec_helper'
require 'decorators/field_service_plan_service_broker_decorator'
require 'field_decorator_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe FieldServicePlanServiceBrokerDecorator do
    describe '.decorate' do
      let(:offering1) { Service.make }
      let(:offering2) { Service.make }

      let(:plan1) { ServicePlan.make(service: offering1) }
      let(:plan2) { ServicePlan.make(service: offering2) }

      it 'decorated the given hash with broker name and guid' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_offering.service_broker': ['name', 'guid'] })

        hash = decorator.decorate(undecorated_hash, [plan1, plan2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_brokers: [
              {
                guid: plan1.service.service_broker.guid,
                name: plan1.service.service_broker.name
              },
              {
                guid: plan2.service.service_broker.guid,
                name: plan2.service.service_broker.name
              }
            ]
          }
        })
      end

      context 'when plans are from the same broker' do
        let(:plan3) { ServicePlan.make(service: offering1) }

        it 'does not duplicate the broker' do
          decorator = described_class.new({ 'service_offering.service_broker': ['name'] })
          hash = decorator.decorate({}, [plan1, plan3])
          expect(hash[:included][:service_brokers]).to have(1).element
        end
      end
    end

    describe '.match?' do
      it_behaves_like 'field decorator match?', 'service_offering.service_broker', ['name', 'guid']
    end
  end
end
