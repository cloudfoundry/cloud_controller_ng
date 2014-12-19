require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe ServiceInstanceDeprovisioner do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }

      let(:name) { 'fake-name' }

      describe 'deprovision' do
        it 'creates a ServiceInstanceDeprovision Job' do
          job = ServiceInstanceDeprovisioner.deprovision(client, service_instance)
          expect(job).to be_instance_of(ServiceInstanceDeprovision)
          expect(job.client).to be(client)
          expect(job.service_instance).to be(service_instance)
        end

        it 'enqueues a ServiceInstanceDeprovision Job' do
          expect(Delayed::Job).to receive(:enqueue).with(an_instance_of(ServiceInstanceDeprovision),
                                                         hash_including(queue: 'cc-generic'))
          ServiceInstanceDeprovisioner.deprovision(client, service_instance)
        end
      end
    end
  end
end
