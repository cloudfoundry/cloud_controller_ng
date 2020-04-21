require 'spec_helper'
require 'decorators/field_service_instance_plan_decorator'

module VCAP::CloudController
  RSpec.describe FieldServiceInstancePlanDecorator do
    describe '.decorate' do
      let(:plan1) { ServicePlan.make }
      let(:plan2) { ServicePlan.make }

      let!(:service_instance_1) { ManagedServiceInstance.make(service_plan: plan1) }
      let!(:service_instance_2) { ManagedServiceInstance.make(service_plan: plan2) }

      it 'decorated the given hash with plan guid and name from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan': ['guid', 'name', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_plans: [
              {
                guid: plan1.guid,
                name: plan1.name,
              },
              {
                guid: plan2.guid,
                name: plan2.name,
              }
            ]
          }
        })
      end

      it 'decorated the given hash with plan relationships to offering' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan': ['relationships.service_offering'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_plans: [
              {
                relationships: {
                  service_offering: {
                    data: {
                      guid: service_instance_1.service_plan.service.guid
                    }
                  }
                }
              },
              {
                relationships: {
                  service_offering: {
                    data: {
                      guid: service_instance_2.service_plan.service.guid
                    }
                  }
                }
              }
            ]
          }
        })
      end

      context 'when instances are from the same plan' do
        let!(:service_instance_3) { ManagedServiceInstance.make(service_plan: plan1) }

        it 'does not duplicate the plan' do
          decorator = described_class.new({ 'service_plan': ['guid'] })
          hash = decorator.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:service_plans]).to have(1).element
        end
      end

      context 'for user provided service instances' do
        let!(:service_instance_3) { UserProvidedServiceInstance.make }

        it 'should return the unchanged hash' do
          undecorated_hash = { foo: 'bar' }
          decorator = described_class.new({ 'service_plan': ['relationships.service_offering'] })

          hash = decorator.decorate(undecorated_hash, [service_instance_3])
          expect(hash[:included]).to be_nil
        end
      end
    end

    describe '.match?' do
      it 'matches hashes containing key symbol `service_plan` and value `guid`' do
        expect(described_class.match?({ 'service_plan': ['guid'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan` and value `name`' do
        expect(described_class.match?({ 'service_plan': ['name'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan` and value `relationships.service_offering`' do
        expect(described_class.match?({ 'service_plan': ['relationships.service_offering'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `service_plan` and value `guid,relationships.service_offering`' do
        expect(described_class.match?({ 'service_plan': ['guid', 'relationships.service_offering', 'something'], other: ['bar'] })).to be_truthy
      end

      it 'does not match other values for a valid key' do
        expect(described_class.match?({ 'service_plan': ['foo'] })).to be_falsey
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
