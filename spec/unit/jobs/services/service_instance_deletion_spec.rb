require 'spec_helper'
require 'jobs/runtime/model_deletion'
require 'models/runtime/app'
require 'models/runtime/space'

module VCAP::CloudController
  module Jobs::Services
    describe ServiceInstanceDeletion do
      let(:service_instance) { ManagedServiceInstance.make }
      subject(:job) { ServiceInstanceDeletion.new(service_instance.guid) }

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        let(:body) { '{}' }
        let(:status) { 200 }

        before do
          service_instance.save_with_operation(
            last_operation: {
              type: 'delete',
              state: 'in progress',
              description: 'description'
            }
          )

          service = service_instance.service
          service_plan = service_instance.service_plan
          guid = service_instance.guid
          plan_id = service_plan.unique_id
          service_id = service.unique_id
          path = "/v2/service_instances/#{guid}?plan_id=#{plan_id}&service_id=#{service_id}"
          uri = URI(service.service_broker.broker_url + path)
          uri.user = service.service_broker.auth_username
          uri.password = service.service_broker.auth_password
          stub_request(:delete, uri.to_s).to_return(body: body, status: status)
        end

        it 'deletes the service instance' do
          expect { job.perform }.to change { ManagedServiceInstance.count }.by(-1)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:model_deletion)
        end

        context 'when the service instance cannot be deprovisioned' do
          let(:status) { 500 }

          it 'sets the last operation to failed' do
            expect {
              job.perform
            }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)

            service_instance.reload
            expect(service_instance.last_operation.type).to eq('delete')
            expect(service_instance.last_operation.state).to eq('failed')
          end
        end
      end
    end
  end
end
