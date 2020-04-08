require 'spec_helper'
require 'decorators/field_service_instance_broker_decorator'

module VCAP::CloudController
  RSpec.describe FieldServiceInstanceBrokerDecorator do
    describe '.decorate' do
      let(:broker) { ServiceBroker.make }
      let(:offering1) { Service.make(service_broker: broker) }
      let(:offering2) { Service.make }

      let(:plan1) { ServicePlan.make(service: offering1) }
      let(:plan2) { ServicePlan.make(service: offering2) }

      let!(:service_instance_1) { ManagedServiceInstance.make(service_plan: plan1) }
      let!(:service_instance_2) { ManagedServiceInstance.make(service_plan: plan2) }

      it 'decorated the given hash with broker name from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering.service_broker': ['name', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_brokers: [
              {
                name: offering1.service_broker.name,
              },
              {
                name: offering2.service_broker.name,
              }
            ]
          }
        })
      end

      it 'decorated the given hash with broker guids from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering.service_broker': ['guid', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_brokers: [
              {
                guid: offering1.service_broker.guid,
              },
              {
                guid: offering2.service_broker.guid,
              }
            ]
          }
        })
      end

      context 'when instances are from the same broker' do
        let(:offering3) { Service.make(service_broker: broker) }
        let(:plan3) { ServicePlan.make(service: offering3) }
        let!(:service_instance_3) { ManagedServiceInstance.make(service_plan: plan3) }

        it 'does not duplicate the broker' do
          decorator = described_class.new({ 'service_plan.service_offering.service_broker': ['name'] })
          hash = decorator.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:service_brokers]).to have(1).element
        end
      end

      context 'for user provided service instances' do
        let!(:service_instance_3) { UserProvidedServiceInstance.make }

        it 'should return the unchanged hash' do
          undecorated_hash = { foo: 'bar' }
          decorator = described_class.new({ 'service_plan.service_offering.service_broker': ['name'] })

          hash = decorator.decorate(undecorated_hash, [service_instance_3])
          expect(hash[:included]).to be_nil
        end
      end
    end

    describe '.match?' do
      it 'matches hashes containing key symbol `service_plan.service_offering.service_broker` and value `name`' do
        expect(described_class.match?({ 'service_plan.service_offering.service_broker': ['name'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan.service_offering.service_broker` and value `guid`' do
        expect(described_class.match?({ 'service_plan.service_offering.service_broker': ['guid'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan.service_offering.service_broker` and value `name,guid`' do
        expect(described_class.match?({ 'service_plan.service_offering.service_broker': ['name', 'guid', 'something'], other: ['bar'] })).to be_truthy
      end

      it 'does not match other values for a valid key' do
        expect(described_class.match?({ 'service_plan.service_offering.service_broker': ['foo'] })).to be_falsey
      end

      it 'does not match other key values' do
        expect(described_class.match?({ other: ['bar'] })).to be_falsey
      end

      it 'does not match non-hashes' do
        expect(described_class.match?('foo')).to be_falsey
      end
    end
  end
end
