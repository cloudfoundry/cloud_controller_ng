require 'spec_helper'
require 'decorators/field_service_instance_offering_decorator'

module VCAP::CloudController
  RSpec.describe FieldServiceInstanceOfferingDecorator do
    describe '.decorate' do
      let(:offering1) { Service.make }
      let(:offering2) { Service.make }

      let(:plan1) { ServicePlan.make(service: offering1) }
      let(:plan2) { ServicePlan.make(service: offering2) }

      let!(:service_instance_1) { ManagedServiceInstance.make(service_plan: plan1) }
      let!(:service_instance_2) { ManagedServiceInstance.make(service_plan: plan2) }

      it 'decorated the given hash with offering name from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering': ['name', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_offerings: [
              {
                name: offering1.name,
              },
              {
                name: offering2.name,
              }
            ]
          }
        })
      end

      it 'decorated the given hash with offering guids from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering': ['guid', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_offerings: [
              {
                guid: offering1.guid,
              },
              {
                guid: offering2.guid,
              }
            ]
          }
        })
      end

      it 'decorated the given hash with offering relationship to broker from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering': ['relationships.service_broker', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_offerings: [
              {
                relationships: {
                  service_broker: {
                    data: {
                      name: offering1.service_broker.name,
                      guid: offering1.service_broker.guid
                    }
                  }
                }
              },
              {
                relationships: {
                  service_broker: {
                    data: {
                      name: offering2.service_broker.name,
                      guid: offering2.service_broker.guid
                    }
                  }
                }
              }
            ]
          }
        })
      end

      context 'when instances are from the same offering' do
        let(:plan3) { ServicePlan.make(service: offering1) }
        let!(:service_instance_3) { ManagedServiceInstance.make(service_plan: plan3) }

        it 'does not duplicate the offering' do
          decorator = described_class.new({ 'service_plan.service_offering': ['name'] })
          hash = decorator.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:service_offerings]).to have(1).element
        end
      end

      context 'for user provided service instances' do
        let!(:service_instance_3) { UserProvidedServiceInstance.make }

        it 'should return the unchanged hash' do
          undecorated_hash = { foo: 'bar' }
          decorator = described_class.new({ 'service_plan.service_offering': ['relationships.service_broker'] })

          hash = decorator.decorate(undecorated_hash, [service_instance_3])
          expect(hash[:included]).to be_nil
        end
      end
    end

    describe '.match?' do
      it 'matches hashes containing key symbol `service_plan.service_offering` and value `name`' do
        expect(described_class.match?({ 'service_plan.service_offering': ['name'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan.service_offering` and value `guid`' do
        expect(described_class.match?({ 'service_plan.service_offering': ['guid'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan.service_offering` and value `relationships.service_broker`' do
        expect(described_class.match?({ 'service_plan.service_offering': ['relationships.service_broker'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan.service_offering` and value `name,guid,relationships.service_broker`' do
        expect(described_class.match?({ 'service_plan.service_offering': ['name', 'guid', 'relationships.service_broker', 'something'], other: ['bar'] })).to be_truthy
      end

      it 'does not match other values for a valid key' do
        expect(described_class.match?({ 'service_plan.service_offering': ['foo'] })).to be_falsey
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
