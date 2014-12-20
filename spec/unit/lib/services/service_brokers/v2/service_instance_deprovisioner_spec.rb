require "spec_helper"

module VCAP::CloudController
  module ServiceBrokers::V2
    describe ServiceInstanceDeprovisioner do
      let(:client_attrs) { {} }

      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan, space: space) }

      let(:name) { 'fake-name' }

      describe 'deprovision' do
        it 'creates a ServiceInstanceDeprovision Job' do
          job = ServiceInstanceDeprovisioner.deprovision(client_attrs, service_instance)
          expect(job).to be_instance_of(VCAP::CloudController::Jobs::Services::ServiceInstanceDeprovision)
          expect(job.client_attrs).to be(client_attrs)
          expect(job.service_instance_guid).to be(service_instance.guid)
          expect(job.service_plan_guid).to be(service_instance.service_plan.guid)
        end

        it 'enqueues a ServiceInstanceDeprovision Job' do
          expect(Delayed::Job).to receive(:enqueue).with(an_instance_of(VCAP::CloudController::Jobs::Services::ServiceInstanceDeprovision),
                                                         hash_including(queue: 'cc-generic'))
          ServiceInstanceDeprovisioner.deprovision(client_attrs, service_instance)
        end
      end
    end
  end
end
