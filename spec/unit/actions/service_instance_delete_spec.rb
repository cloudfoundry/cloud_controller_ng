require 'spec_helper'
require 'actions/service_instance_delete'

module VCAP::CloudController
  describe ServiceInstanceDelete do
    subject(:service_instance_delete) { ServiceInstanceDelete.new }

    describe '#delete' do
      let!(:service_instance_1) { ManagedServiceInstance.make }
      let!(:service_instance_2) { ManagedServiceInstance.make }

      let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance_1) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance_2) }

      let!(:service_instance_dataset) { ServiceInstance.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        [service_instance_1, service_instance_2].each do |service_instance|
          stub_deprovision(service_instance)
          stub_unbind(service_instance.service_bindings.first)
        end
      end

      it 'deletes all the service_instances' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceInstance.count }.by(-2)
      end

      it 'deletes all the bindings for all the service instance' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceBinding.count }.by(-2)
      end

      it 'deletes user provided service instances' do
        user_provided_instance = UserProvidedServiceInstance.make
        service_instance_delete.delete(service_instance_dataset)
        expect { user_provided_instance.refresh }.to raise_error('Record not found')
      end

      it 'deletes the last operation for each managed service instance' do
        instance_operation_1 = ServiceInstanceOperation.make(state: 'succeeded')
        service_instance_1.service_instance_operation = instance_operation_1
        service_instance_1.save

        service_instance_delete.delete(service_instance_dataset)

        expect { service_instance_1.refresh }.to raise_error('Record not found')
        expect { instance_operation_1.refresh }.to raise_error('Record not found')
      end

      it 'defaults accepts_incomplete to false' do
        service_instance_delete.delete([service_instance_1])
        broker_url = service_instance_deprovision_url(service_instance_1, accepts_incomplete: nil)
        expect(a_request(:delete, broker_url)).to have_been_made
      end

      context 'when accepts_incomplete is true' do
        let(:service_instance) { ManagedServiceInstance.make }
        let(:last_operation_hash) do
          {
            last_operation: {
              state: 'in progress',
              description: 'description'
            }
          }
        end
        subject(:service_instance_delete) { ServiceInstanceDelete.new(accepts_incomplete: true) }

        before do
          stub_deprovision(service_instance, accepts_incomplete: true, status: 202, body: last_operation_hash.to_json)
        end

        it 'passes the accepts_incomplete flag to the client call' do
          service_instance_delete.delete([service_instance])
          broker_url = service_instance_deprovision_url(service_instance, accepts_incomplete: true)
          expect(a_request(:delete, broker_url)).to have_been_made
        end

        it 'updates the instance with the values provided by the broker' do
          service_instance_delete.delete([service_instance])
          expect(service_instance.last_operation.state).to eq 'in progress'
          expect(service_instance.last_operation.description).to eq 'description'
        end
      end

      context 'when unbinding a service instance times out' do
        before do
          stub_unbind(service_binding_1, body: lambda { |r|
            sleep 10
            raise 'Should time out'
          })
        end

        it 'should leave the service instance unchanged' do
          original_attrs = service_binding_1.as_json
          expect {
            Timeout.timeout(0.5.second) do
              service_instance_delete.delete(service_instance_dataset)
            end
          }.to raise_error(Timeout::Error)

          service_binding_1.reload

          expect(a_request(:delete, service_instance_unbind_url(service_binding_1))).
            to have_been_made.times(1)
          expect(service_binding_1.as_json).to eq(original_attrs)

          expect(ServiceInstance.first(id: service_instance_1.id)).to be
        end
      end

      context 'when deprovisioning a service instance times out' do
        before do
          stub_deprovision(service_instance_1, body: lambda { |r|
            sleep 10
            raise 'Should time out'
          })
        end

        it 'should mark the service instance as failed' do
          expect {
            Timeout.timeout(0.5.second) do
              service_instance_delete.delete(service_instance_dataset)
            end
          }.to raise_error(Timeout::Error)

          service_instance_1.reload

          expect(a_request(:delete, service_instance_deprovision_url(service_instance_1))).
            to have_been_made.times(1)
          expect(service_instance_1.last_operation.type).to eq('delete')
          expect(service_instance_1.last_operation.state).to eq('failed')
        end
      end

      context 'when the broker returns an error for one of the deletions' do
        before do
          stub_deprovision(service_instance_2, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete(service_instance_dataset)
          expect(ServiceInstance.count).to eq 1
        end

        it 'returns errors it has captured' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end
      end

      context 'when the broker returns an error for unbinding' do
        before do
          stub_unbind(service_instance_2.service_bindings.first, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete(service_instance_dataset)
          expect(ServiceInstance.count).to eq 1
        end

        it 'propagates service unbind errors' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end
      end

      context 'when deletion from the database fails for a service instance' do
        before do
          allow(service_instance_2).to receive(:destroy).and_raise('BOOM')
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete([service_instance_1, service_instance_2])
          expect(ServiceInstance.count).to eq 1
        end

        it 'returns errors it has captured' do
          errors = service_instance_delete.delete([service_instance_1, service_instance_2])
          expect(errors.count).to eq(1)
          expect(errors[0].message).to eq 'BOOM'
        end
      end
    end
  end
end
