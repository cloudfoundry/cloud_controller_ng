require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe ServiceInstanceUnbinder do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }
      let(:binding) do
        VCAP::CloudController::ServiceBinding.make(
          binding_options: { 'this' => 'that' }
        )
      end
      let(:name) { 'fake-name' }

      describe 'unbind' do
        it 'creates a ServiceInstanceUnbind Job' do
          job = ServiceInstanceUnbinder.unbind(client, binding)
          expect(job).to be_instance_of(ServiceInstanceUnbind)
          expect(job.client).to be(client)
          expect(job.binding).to be(binding)
        end

        it 'enqueues a ServiceInstanceUnbind Job' do
          Timecop.freeze do
            expect(Delayed::Job).to receive(:enqueue).with(an_instance_of(ServiceInstanceUnbind),
                                                           hash_including(queue: 'cc-generic'))
            ServiceInstanceUnbinder.unbind(client, binding)
          end
        end
      end
    end
  end
end
