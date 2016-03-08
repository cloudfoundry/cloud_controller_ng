require 'spec_helper'
require 'cloud_controller/metrics/varz_updater'

module VCAP::CloudController::Metrics
  describe VarzUpdater do
    let(:varz) { VarzUpdater.new }

    describe '#record_user_count' do
      it 'should include the number of users in varz' do
        # We have to use stubbing here because when we run in parallel mode,
        # there might other tests running and create/delete users concurrently.
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:cc_user_count] = 0
        end

        expected_user_count = 5

        varz.record_user_count(expected_user_count)

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:cc_user_count]).to eql(expected_user_count)
        end
      end
    end

    describe '#update_job_queue_length' do
      it 'should include the length of the delayed job queues and total' do
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:cc_job_queue_length] = 0
        end

        expected_local_length   = 5
        expected_generic_length = 6
        total                   = expected_local_length + expected_generic_length

        pending_job_count_by_queue = {
          cc_local:   expected_local_length,
          cc_generic: expected_generic_length
        }

        varz.update_job_queue_length(pending_job_count_by_queue, total)

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:cc_job_queue_length][:cc_local]).to eq(expected_local_length)
          expect(VCAP::Component.varz[:cc_job_queue_length][:cc_generic]).to eq(expected_generic_length)
          expect(VCAP::Component.varz[:cc_job_queue_length][:total]).to eq(total)
        end
      end
    end

    describe '#update_failed_job_count' do
      it 'includes the number of failed jobs in the delayed job queue and the total' do
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:cc_failed_job_count] = 0
        end

        expected_local_length   = 5
        expected_generic_length = 6
        total                   = expected_local_length + expected_generic_length

        failed_jobs_by_queue = {
          cc_local:   expected_local_length,
          cc_generic: expected_generic_length
        }

        varz.update_failed_job_count(failed_jobs_by_queue, total)

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:cc_failed_job_count][:cc_local]).to eq(expected_local_length)
          expect(VCAP::Component.varz[:cc_failed_job_count][:cc_generic]).to eq(expected_generic_length)
          expect(VCAP::Component.varz[:cc_failed_job_count][:total]).to eq(total)
        end
      end
    end

    describe '#update_thread_info' do
      it 'should contain EventMachine data' do
        thread_info = {
          thread_count:  5,
          event_machine: {
            connection_count: 10,
            threadqueue:      {
              size:        19,
              num_waiting: 2,
            },
            resultqueue: {
              size:        8,
              num_waiting: 1,
            },
          },
        }

        varz.update_thread_info(thread_info)

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:thread_info][:thread_count]).to eq(5)
          expect(VCAP::Component.varz[:thread_info][:event_machine][:connection_count]).to eq(10)
          expect(VCAP::Component.varz[:thread_info][:event_machine][:threadqueue][:size]).to eq(19)
          expect(VCAP::Component.varz[:thread_info][:event_machine][:threadqueue][:num_waiting]).to eq(2)
          expect(VCAP::Component.varz[:thread_info][:event_machine][:resultqueue][:size]).to eq(8)
          expect(VCAP::Component.varz[:thread_info][:event_machine][:resultqueue][:num_waiting]).to eq(1)
        end
      end
    end

    describe '#update_vitals' do
      # noop
    end

    describe '#update_log_counts' do
      # noop
    end

    describe '#update_task_stats' do
      # noop
    end
  end
end
