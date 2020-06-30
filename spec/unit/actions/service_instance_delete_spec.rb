require 'spec_helper'
require 'actions/service_instance_delete'

module VCAP::CloudController
  RSpec.describe ServiceInstanceDelete do
    describe '#delete' do
      subject(:action) { described_class.new(event_repository) }
      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_user_provided_service_instance_event)
        dbl
      end

      let!(:service_instance) do
        si = VCAP::CloudController::UserProvidedServiceInstance.make(
          name: 'foo',
          credentials: {
            foo: 'bar',
            baz: 'qux'
          },
          syslog_drain_url: 'https://foo.com',
          route_service_url: 'https://bar.com',
          tags: %w(accounting mongodb)
        )
        si.label_ids = [
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
        ]
        si.annotation_ids = [
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
        ]
        si
      end

      it 'deletes an user provided service instance from the database' do
        subject.delete(service_instance)

        expect {
          service_instance.reload
        }.to raise_error(Sequel::Error, 'Record not found')
        expect(VCAP::CloudController::ServiceInstanceLabelModel.where(service_instance: service_instance)).to be_empty
        expect(VCAP::CloudController::ServiceInstanceAnnotationModel.where(service_instance: service_instance)).to be_empty
      end

      it 'fails to delete managed service instances' do
        instance = VCAP::CloudController::ManagedServiceInstance.make
        expect { subject.delete(instance) }.to raise_error(ServiceInstanceDelete::NotImplementedError)
        expect { instance.reload }.not_to raise_error
      end

      it 'creates an audit event' do
        subject.delete(service_instance)

        expect(event_repository).
          to have_received(:record_user_provided_service_instance_event).
          with(:delete, instance_of(UserProvidedServiceInstance), {})
      end

      describe 'invalid pre-conditions' do
        context 'when there are associated service bindings' do
          before do
            VCAP::CloudController::ServiceBinding.make(service_instance: service_instance)
          end

          it 'does not delete the service instance' do
            expect { subject.delete(service_instance) }.to raise_error(ServiceInstanceDelete::AssociationNotEmptyError)
            expect { service_instance.reload }.not_to raise_error
          end
        end

        context 'when there are associated service keys' do
          before do
            VCAP::CloudController::ServiceKey.make(service_instance: service_instance)
          end

          it 'does not delete the service instance' do
            expect { subject.delete(service_instance) }.to raise_error(ServiceInstanceDelete::AssociationNotEmptyError)
            expect { service_instance.reload }.not_to raise_error
          end
        end

        context 'when there are associated route bindings' do
          before do
            VCAP::CloudController::RouteBinding.make(
              service_instance: service_instance,
              route: VCAP::CloudController::Route.make(space: service_instance.space)
            )
          end

          it 'does not delete the service instance' do
            expect { subject.delete(service_instance) }.to raise_error(ServiceInstanceDelete::AssociationNotEmptyError)
            expect { service_instance.reload }.not_to raise_error
          end
        end

        context 'when the service instance is shared' do
          let(:space) { VCAP::CloudController::Space.make }
          let(:other_space) { VCAP::CloudController::Space.make }
          let!(:service_instance) {
            si = VCAP::CloudController::ServiceInstance.make(space: space)
            si.shared_space_ids = [other_space.id]
            si
          }

          it 'does not delete the service instance' do
            expect { subject.delete(service_instance) }.to raise_error(ServiceInstanceDelete::InstanceSharedError)
            expect { service_instance.reload }.not_to raise_error
          end
        end
      end
    end
  end
end
