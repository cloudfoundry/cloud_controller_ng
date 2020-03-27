require 'spec_helper'
require 'actions/service_instance_create_managed'
require 'messages/service_instance_create_managed_message'

module VCAP
  module CloudController
    RSpec.describe ServiceInstanceCreateManaged do
      subject(:action) { described_class.new(event_repository) }

      let(:maintenance_info) do
        {
          'version' => '0.1.2',
          'description' => 'amazing plan'
        }
      end
      let(:service_plan) { ServicePlan.make(maintenance_info: maintenance_info) }
      let(:space) { Space.make }
      let(:name) { 'my-service-instance' }
      let(:message) { ServiceInstanceCreateManagedMessage.new(request) }
      let(:instance) { ServiceInstance.last }

      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_service_instance_event)
        dbl
      end

      let(:request) do
        {
          type: 'managed',
          name: name,
          parameters: {
            foo: 'bar',
            baz: 'qux'
          },
          tags: %w(foo bar baz),
          relationships: {
            space: {
              data: {
                guid: space.guid
              }
            },
            service_plan: {
              data: {
                guid: service_plan.guid
              }
            }
          },
          metadata: {
            labels: { potato: 'mashed' },
            annotations: { cheese: 'bono' }
          }
        }
      end

      it 'creates a managed service instance' do
        action.create(message)

        expect(instance).to be_a(ManagedServiceInstance)
        expect(instance.name).to eq('my-service-instance')
        expect(instance.tags).to contain_exactly('foo', 'bar', 'baz')
        expect(instance.space).to eq(space)
        expect(instance.service_plan).to eq(service_plan)
        expect(instance.maintenance_info).to eq(maintenance_info)

        expect(instance.labels[0].key_name).to eq('potato')
        expect(instance.labels[0].value).to eq('mashed')
        expect(instance.annotations[0].key_name).to eq('cheese')
        expect(instance.annotations[0].value).to eq('bono')
      end

      it 'sets a `last_operation` type of `create in progress' do
        action.create(message)
        last_operation = instance.last_operation

        expect(last_operation.type).to eq('create')
        expect(last_operation.state).to eq('in progress')
      end

      it 'creates an audit event' do
        action.create(message)

        expect(event_repository).
          to have_received(:record_service_instance_event).with(
            :start_create,
            instance_of(ManagedServiceInstance),
            request.with_indifferent_access
          )
      end

      it 'returns a pollable job' do
        result = action.create(message)

        expect(result).to be_a(PollableJobModel)
        expect(result.operation).to eq('service_instance.create')
      end

      context 'minimum parameters' do
        let(:request) do
          {
            type: 'managed',
            name: 'my-service-instance',
            relationships: {
              space: {
                data: {
                  guid: space.guid
                }
              },
              service_plan: {
                data: {
                  guid: service_plan.guid
                }
              }
            }
          }
        end

        it 'creates a managed service instance' do
          action.create(message)

          expect(instance).to be_a(ManagedServiceInstance)
          expect(instance.name).to eq('my-service-instance')
          expect(instance.space).to eq(space)
          expect(instance.service_plan).to eq(service_plan)
        end
      end

      context 'service plan not found' do
        it 'raises an error' do
          allow(message).to receive(:service_plan_guid).and_return('invalid-plan')

          expect { action.create(message) }.
            to raise_error(ServiceInstanceCreateManaged::InvalidManagedServiceInstance, 'Service plan not found.')
        end
      end

      context 'name is already taken' do
        it 'raises an error' do
          ServiceInstance.make(name: name, space: space)

          expect { action.create(message) }.
            to raise_error(
              ServiceInstanceCreateManaged::InvalidManagedServiceInstance,
              "The service instance name is taken: #{name}"
            )
        end
      end

      context 'SQL validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect_any_instance_of(ManagedServiceInstance).to receive(:save_with_new_operation).
            and_raise(Sequel::ValidationFailed.new(errors))

          expect { action.create(message) }.
            to raise_error(ServiceInstanceCreateManaged::InvalidManagedServiceInstance, 'blork is busted')
        end
      end
    end
  end
end
