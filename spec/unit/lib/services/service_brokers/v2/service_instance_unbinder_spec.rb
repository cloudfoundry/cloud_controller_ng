require 'spec_helper'

module VCAP::CloudController
  module ServiceBrokers::V2
    describe ServiceInstanceUnbinder do
      let(:client_attrs) { {} }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          binding_options: { 'this' => 'that' }
        )
      end
      let(:name) { 'fake-name' }

      describe 'delayed_unbind' do
        it 'creates a ServiceInstanceUnbind Job' do
          job = ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)
          expect(job).to be_instance_of(VCAP::CloudController::Jobs::Services::ServiceInstanceUnbind)
          expect(job.client_attrs).to be(client_attrs)
          expect(job.binding_guid).to be(binding.guid)
          expect(job.service_instance_guid).to be(binding.service_instance.guid)
          expect(job.app_guid).to be(binding.app.guid)
        end

        it 'enqueues a ServiceInstanceUnbind Job' do
          expect(Delayed::Job).to receive(:enqueue).with(an_instance_of(VCAP::CloudController::Jobs::Services::ServiceInstanceUnbind),
                                                         hash_including(queue: 'cc-generic'))
          ServiceInstanceUnbinder.delayed_unbind(client_attrs, binding)
        end
      end
    end
  end
end
