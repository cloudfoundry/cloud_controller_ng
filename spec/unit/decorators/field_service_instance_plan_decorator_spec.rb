require 'spec_helper'
require 'decorators/field_service_instance_plan_decorator'
require 'field_decorator_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe FieldServiceInstancePlanDecorator do
    describe '.decorate' do
      let(:plan1) { ServicePlan.make(created_at: Time.now.utc - 1.second) }
      let(:plan2) { ServicePlan.make }

      let(:service_instance_1) { ManagedServiceInstance.make(service_plan: plan1) }
      let(:service_instance_2) { ManagedServiceInstance.make(service_plan: plan2) }

      it 'decorated the given hash with plan guid, name and broker_catalog.id from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
        decorator = described_class.new({ service_plan: %w[guid name broker_catalog.id foo] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
                                foo: 'bar',
                                included: {
                                  monkeys: %w[zach greg],
                                  service_plans: [
                                    {
                                      guid: plan1.guid,
                                      name: plan1.name,
                                      broker_catalog: {
                                        id: plan1.unique_id
                                      }
                                    },
                                    {
                                      guid: plan2.guid,
                                      name: plan2.name,
                                      broker_catalog: {
                                        id: plan2.unique_id
                                      }
                                    }
                                  ]
                                }
                              })
      end

      it 'decorated the given hash with plan relationships to offering' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
        decorator = described_class.new({ service_plan: ['relationships.service_offering'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
                                foo: 'bar',
                                included: {
                                  monkeys: %w[zach greg],
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
        let(:service_instance_3) { ManagedServiceInstance.make(service_plan: plan1) }

        it 'does not duplicate the plan' do
          decorator = described_class.new({ service_plan: ['guid'] })
          hash = decorator.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:service_plans]).to have(1).element
        end
      end

      context 'for user provided service instances' do
        let(:service_instance_3) { UserProvidedServiceInstance.make }

        it 'returns the unchanged hash' do
          undecorated_hash = { foo: 'bar' }
          decorator = described_class.new({ service_plan: ['relationships.service_offering'] })

          hash = decorator.decorate(undecorated_hash, [service_instance_3])
          expect(hash[:included]).to be_nil
        end
      end
    end

    describe '.match?' do
      it_behaves_like 'field decorator match?', 'service_plan', ['name', 'guid', 'broker_catalog.id', 'relationships.service_offering']
    end
  end
end
