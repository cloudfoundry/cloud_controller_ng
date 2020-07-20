require 'spec_helper'
require 'decorators/field_service_instance_offering_decorator'

module VCAP::CloudController
  RSpec.describe FieldServiceInstanceOfferingDecorator do
    describe '.decorate' do
      let(:offering1) { Service.make(extra: '{"documentationUrl": "https://offering1.com"}', tags: %w(foo bar)) }
      let(:offering2) { Service.make(extra: '{"documentationUrl": "https://offering2.com"}', tags: %w(baz)) }

      let(:plan1) { ServicePlan.make(service: offering1) }
      let(:plan2) { ServicePlan.make(service: offering2) }

      let!(:service_instance_1) { ManagedServiceInstance.make(service_plan: plan1) }
      let!(:service_instance_2) { ManagedServiceInstance.make(service_plan: plan2) }

      it 'can decorate with the service offering name' do
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

      it 'can decorate with the service offering guid' do
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

      it 'can decorate with the service offering description' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering': ['description', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_offerings: [
              {
                description: offering1.description,
              },
              {
                description: offering2.description,
              }
            ]
          }
        })
      end

      it 'can decorate with the service offering documentation' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering': ['documentation_url', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_offerings: [
              {
                documentation_url: 'https://offering1.com',
              },
              {
                documentation_url: 'https://offering2.com',
              }
            ]
          }
        })
      end

      it 'can decorate with the service offering tags' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'service_plan.service_offering': ['tags', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            service_offerings: [
              {
                tags: offering1.tags,
              },
              {
                tags: offering2.tags,
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
                      guid: offering1.service_broker.guid
                    }
                  }
                }
              },
              {
                relationships: {
                  service_broker: {
                    data: {
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
      fields = %w(name guid description documentation_url tags relationships.service_broker)

      fields.each do |field|
        it "matches value `#{field}` for key symbol `service_plan.service_offering`" do
          expect(described_class.match?({ 'service_plan.service_offering': [field], other: ['bar'] })).to be_truthy
        end
      end

      it 'matches all fields together for key symbol `service_plan.service_offering`' do
        expect(described_class.match?({ 'service_plan.service_offering': fields, other: ['bar'] })).to be_truthy
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
