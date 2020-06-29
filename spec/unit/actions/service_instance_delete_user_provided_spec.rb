require 'spec_helper'
require 'actions/service_instance_delete_user_provided'

module VCAP::CloudController
  RSpec.describe ServiceInstanceDeleteUserProvided do
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

      it 'deletes the service instance from the database' do
        subject.delete(service_instance)

        expect {
          service_instance.reload
        }.to raise_error(Sequel::Error, 'Record not found')
        expect(VCAP::CloudController::ServiceInstanceLabelModel.where(service_instance: service_instance)).to be_empty
        expect(VCAP::CloudController::ServiceInstanceAnnotationModel.where(service_instance: service_instance)).to be_empty
      end

      it 'creates an audit event' do
        subject.delete(service_instance)

        expect(event_repository).
          to have_received(:record_user_provided_service_instance_event).
          with(:delete, instance_of(UserProvidedServiceInstance), {})
      end

      context 'when there are associated service bindings' do
        before do
          VCAP::CloudController::ServiceBinding.make(service_instance: service_instance)
        end

        it 'does not delete the service instance' do
          expect {
            subject.delete(service_instance)
          }.to raise_error(
            ServiceInstanceDeleteUserProvided::AssociationNotEmptyError,
          )
        end
      end

      context 'when there are associated service keys' do
        before do
          VCAP::CloudController::ServiceKey.make(service_instance: service_instance)
        end

        it 'does not delete the service instance' do
          expect {
            subject.delete(service_instance)
          }.to raise_error(
            ServiceInstanceDeleteUserProvided::AssociationNotEmptyError,
          )
        end
      end
    end
  end
end
