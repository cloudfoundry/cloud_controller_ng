require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe CreateServiceInstanceJob do
        it_behaves_like 'delayed job', described_class

        let(:maintenance_info) { { 'version' => '1.2.0' } }
        let(:params) { { some_data: 'some_value' } }
        let(:plan) { ServicePlan.make(maintenance_info: maintenance_info) }
        let(:service_instance) { ManagedServiceInstance.make(service_plan: plan) }
        let(:user_info) { instance_double(Object) }
        let(:subject) {
          described_class.new(
            service_instance.guid,
            arbitrary_parameters: params,
            user_audit_info: user_info
          )
        }

        describe '#operation' do
          it 'returns "provision"' do
            expect(subject.operation).to eq(:provision)
          end
        end

        describe '#operation_type' do
          it 'returns "create"' do
            expect(subject.operation_type).to eq('create')
          end
        end

        describe '#send_broker_request' do
          let(:client) { double('BrokerClient', provision: 'some response') }

          it 'sends a provision request' do
            subject.send_broker_request(client)

            expect(client).to have_received(:provision).with(
              service_instance,
              accepts_incomplete: true,
              arbitrary_parameters: params,
              maintenance_info: maintenance_info
            )
          end

          it 'returns the client response' do
            response = subject.send_broker_request(client)
            expect(response).to eq('some response')
          end
        end
      end
    end
  end
end
