require 'spec_helper'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceInstanceJob do
      it_behaves_like 'delayed job', described_class

      let(:service_offering) { Service.make }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) {
        ManagedServiceInstance.make(service_plan: service_plan)
      }

      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
      let(:subject) { described_class.new(service_instance.guid, user_audit_info) }

      describe '#operation' do
        it 'returns "deprovision"' do
          expect(subject.operation).to eq(:deprovision)
        end
      end

      describe '#operation_type' do
        it 'returns "delete"' do
          expect(subject.operation_type).to eq('delete')
        end
      end

      describe '#send_broker_request' do
        let(:client) { double('BrokerClient', deprovision: 'some response') }

        it 'sends a deprovision request' do
          subject.send_broker_request(client)

          expect(client).to have_received(:deprovision).with(
            service_instance,
            accepts_incomplete: true,
          )
        end

        it 'returns the client response' do
          response = subject.send_broker_request(client)
          expect(response).to eq('some response')
        end

        context 'when the client raises a ServiceBrokerBadResponse' do
          it 'raises a DeprovisionBadResponse error' do
            r = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: '204', body: 'unexpected failure!')
            err = VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new(nil, :delete, r)
            allow(client).to receive(:deprovision).and_raise(err)

            expect { subject.send_broker_request(client) }.to raise_error(DeprovisionBadResponse, /unexpected failure!/)
          end
        end

        context 'when the client raises an unknown error' do
          it 'raises the error' do
            allow(client).to receive(:deprovision).and_raise(RuntimeError.new('oh boy'))
            expect { subject.send_broker_request(client) }.to raise_error(RuntimeError, 'oh boy')
          end
        end
      end

      describe '#gone!' do
        it 'finishes the job' do
          job = DeleteServiceInstanceJob.new(service_instance.guid, user_audit_info)
          expect { job.gone! }.not_to raise_error
          expect(job.finished).to eq(true)
        end
      end

      describe '#operation_succeeded' do
        it 'deletes the service instance from the db' do
          expect(ManagedServiceInstance.first(guid: service_instance.guid)).not_to be_nil
          subject.operation_succeeded
          expect(ManagedServiceInstance.first(guid: service_instance.guid)).to be_nil
        end
      end

      describe '#trigger_orphan_mitigation?' do
        it 'returns true for DeprovisionBadResponse errors' do
          expect(subject.trigger_orphan_mitigation?(DeprovisionBadResponse.new('some message'))).to eq(true)
        end

        it 'returns false for other types of errors' do
          expect(subject.trigger_orphan_mitigation?(RuntimeError.new('boom'))).to eq(false)
        end
      end

      describe '#restart_on_failure?' do
        it 'returns true' do
          expect(subject.restart_on_failure?).to eq(true)
        end
      end
    end
  end
end
