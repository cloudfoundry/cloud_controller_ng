require 'spec_helper'

module VCAP::Services
  module ServiceBrokers::V2
    describe OrphanMitigator do
      let(:client_attrs) { { uri: 'broker.com' } }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          binding_options: { 'this' => 'that' }
        )
      end
      let(:name) { 'fake-name' }

      describe 'cleanup_failed_provision' do
        it 'enqueues a deprovison job' do
          mock_enqueuer = double(:enqueuer, enqueue: nil)
          allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)

          OrphanMitigator.cleanup_failed_provision(client_attrs, service_instance)

          expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new) do |job, opts|
            expect(opts[:queue]).to eq 'cc-generic'
            expect(opts[:run_at]).to be_within(0.01).of(Delayed::Job.db_time_now)

            expect(job).to be_a VCAP::CloudController::Jobs::Services::ServiceInstanceDeprovision
            expect(job.name).to eq 'service-instance-deprovision'
            expect(job.client_attrs).to eq client_attrs
            expect(job.service_instance_guid).to eq service_instance.guid
            expect(job.service_plan_guid).to eq service_instance.service_plan.guid
          end

          expect(mock_enqueuer).to have_received(:enqueue)
        end
      end

      describe 'cleanup_failed_bind' do
        it 'enqueues an unbind job' do
          mock_enqueuer = double(:enqueuer, enqueue: nil)
          allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)

          OrphanMitigator.cleanup_failed_bind(client_attrs, binding)

          expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new) do |job, opts|
            expect(opts[:queue]).to eq 'cc-generic'
            expect(opts[:run_at]).to be_within(0.01).of(Delayed::Job.db_time_now)

            expect(job).to be_a VCAP::CloudController::Jobs::Services::ServiceInstanceUnbind
            expect(job.name).to eq 'service-instance-unbind'
            expect(job.client_attrs).to eq client_attrs
            expect(job.binding_guid).to eq binding.guid
            expect(job.service_instance_guid).to eq binding.service_instance.guid
            expect(job.app_guid).to eq binding.app.guid
          end

          expect(mock_enqueuer).to have_received(:enqueue)
        end
      end
    end
  end
end
