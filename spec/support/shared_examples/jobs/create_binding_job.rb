require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/create_service_binding_job_factory'

RSpec.shared_examples 'create binding job' do |binding_type|
  it_behaves_like 'delayed job', described_class

  let(:subject) do
    described_class.new(
      binding_type,
      binding.guid,
      parameters: parameters,
      user_audit_info: user_info,
      audit_hash: {}
    )
  end

  let(:space) { VCAP::CloudController::Space.make }
  let(:service_offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }
  let(:maximum_polling_duration) { nil }
  let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(service_plan: service_plan, space: space) }

  let(:user_info) { instance_double(Object) }
  let(:parameters) { { foo: 'bar' } }

  describe '#perform' do
    let(:poll_response) { { finished: false } }
    let(:action) do
      double('BindingAction', {
        bind: nil,
        poll: poll_response
      })
    end

    before do
      allow(VCAP::CloudController::V3::CreateServiceBindingFactory).to receive(:action).and_return(action)
    end

    context 'first time' do
      context 'synchronous response' do
        before do
          binding.save_with_attributes_and_new_operation({}, { type: 'create', state: 'succeeded' })
        end

        it 'calls bind and then finishes' do
          subject.perform

          expect(action).to have_received(:bind).with(
            binding,
            parameters: parameters,
            accepts_incomplete: true,
          )

          expect(subject.finished).to be_truthy
        end
      end

      context 'asynchronous response' do
        context 'computes the maximum duration' do
          before do
            TestConfig.override({
              broker_client_max_async_poll_duration_minutes: 90009
            })
            subject.perform
          end

          it 'sets to the default value' do
            expect(subject.maximum_duration_seconds).to eq(90009.minutes)
          end

          context 'when the plan defines a duration' do
            let(:maximum_polling_duration) { 7465 }

            it 'sets to the plan value' do
              expect(subject.maximum_duration_seconds).to eq(7465)
            end
          end
        end
        it 'calls bind and then poll' do
          subject.perform

          expect(action).to have_received(:bind).with(
            binding,
            parameters: parameters,
            accepts_incomplete: true,
          )

          expect(action).to have_received(:poll).with(binding)

          expect(subject.finished).to be_falsey
        end

        context 'bind fails with BindingNotRetrievable' do
          before do
            allow(action).to receive(:bind).and_raise(VCAP::CloudController::V3::ServiceRouteBindingCreate::BindingNotRetrievable)
          end

          it 'raises an API error' do
            expect {
              subject.perform
            }.to raise_error(
              CloudController::Errors::ApiError,
              'The service binding is invalid: The broker responded asynchronously but does not support fetching binding data'
            )
          end
        end
      end
    end

    context 'subsequent times' do
      let(:new_action) do
        double('BindingDouble', {
          bind: nil,
          poll: poll_response,
        })
      end

      before do
        allow(VCAP::CloudController::V3::CreateServiceBindingFactory).to receive(:action).and_return(new_action)
        subject.perform
      end

      it 'only calls poll' do
        subject.perform
        expect(new_action).to have_received(:bind).once
        expect(new_action).to have_received(:poll).with(binding).twice

        expect(subject.finished).to be_falsey
      end

      context 'poll indicates binding complete' do
        let(:poll_response) { { finished: true } }

        it 'finishes the job' do
          subject.perform

          expect(subject.finished).to be_truthy
        end
      end

      context 'the maximum duration' do
        it 'recomputes the value' do
          subject.maximum_duration_seconds = 90009
          TestConfig.override({ broker_client_max_async_poll_duration_minutes: 8088 })
          subject.perform
          expect(subject.maximum_duration_seconds).to eq(8088.minutes)
        end

        context 'when the plan value changes between calls' do
          before do
            subject.maximum_duration_seconds = 90009
            service_plan.update(maximum_polling_duration: 5000)
            subject.perform
          end

          it 'sets to the new plan value' do
            expect(subject.maximum_duration_seconds).to eq(5000)
          end
        end
      end

      context 'when the operation changes' do
        before do
          binding.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'in progress' })
        end

        it 'raises an error' do
          expect { subject.perform }.to raise_error(
            CloudController::Errors::ApiError,
              /create could not be completed: delete in progress/
          )

          binding.reload
          expect(binding.last_operation.state).to eq('in progress')
          expect(binding.last_operation.type).to eq('delete')
        end
      end
    end

    context 'retry interval' do
      def test_retry_after(value, expected)
        allow(action).to receive(:poll).and_return({ finished: false, retry_after: value })
        subject.perform
        expect(subject.polling_interval_seconds).to eq(expected)
      end

      it 'updates the polling interval' do
        test_retry_after(10, 60) # below default
        test_retry_after(65, 65)
        test_retry_after(1.hour, 1.hour)
        test_retry_after(25.hours, 24.hours) # above limit
      end
    end

    context 'binding not found' do
      it 'raises an API error' do
        binding.destroy

        expect { subject.perform }.to raise_error(
          VCAP::CloudController::V3::CreateBindingAsyncJob::BindingNotFound,
          /The binding could not be found/,
        )
      end
    end

    context 'bind fails' do
      it 'raises an API error' do
        allow(action).to receive(:bind).and_raise(StandardError)

        expect { subject.perform }.to raise_error(
          CloudController::Errors::ApiError,
          'bind could not be completed: StandardError',
        )

        binding.reload
        expect(binding.last_operation.type).to eq('create')
        expect(binding.last_operation.state).to eq('failed')
      end
    end

    context 'poll fails' do
      it 'raises an API error' do
        allow(action).to receive(:poll).and_raise(StandardError)

        expect { subject.perform }.to raise_error(
          CloudController::Errors::ApiError,
          'bind could not be completed: StandardError',
        )

        binding.reload
        expect(binding.last_operation.type).to eq('create')
        expect(binding.last_operation.state).to eq('failed')
      end
    end
  end

  describe '#handle_timeout' do
    it 'updates the last operation to failed' do
      subject.handle_timeout

      binding.reload
      expect(binding.last_operation.type).to eq('create')
      expect(binding.last_operation.state).to eq('failed')
      expect(binding.last_operation.description).to eq('Service Broker failed to bind within the required time.')
    end
  end
end
