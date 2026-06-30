require 'spec_helper'
require 'delayed_job/local_worker_drain_plugin'
require 'jobs/queues'

RSpec.describe LocalWorkerDrainPlugin do
  let(:worker) { Delayed::Worker.new }

  before do
    @original_queues = Delayed::Worker.queues
    Delayed::Worker.exit_on_complete = false
    allow(worker).to receive(:reload!)
    allow(worker).to receive(:say)
  end

  after do
    Delayed::Worker.queues = @original_queues
    Delayed::Worker.exit_on_complete = false
  end

  describe 'TERM signal handling' do
    context 'when the worker is processing a local queue' do
      before do
        Delayed::Worker.queues = ['cc-api_worker.cloud_controller_ng.0.1']
        Delayed::Worker.sleep_delay = 0
      end

      after { Delayed::Worker.sleep_delay = Delayed::Worker::DEFAULT_SLEEP_DELAY }

      it 'works off all remaining jobs in the queue before exiting' do
        work_off_calls = Queue.new
        allow(worker).to receive(:work_off) do
          work_off_calls.push(:called)
          work_off_calls.size < 3 ? [1, 0] : [0, 0]
        end

        worker_thread = Thread.new { worker.start }
        work_off_calls.pop # wait until worker has started
        Process.kill('TERM', Process.pid)
        worker_thread.join(5)

        expect(worker_thread.alive?).to be(false)
        expect(work_off_calls.size).to eq(3)
      end
    end

    context 'when the worker is processing the generic queue' do
      before do
        Delayed::Worker.queues = ['cc-generic']
        allow(worker).to receive(:trap).with('QUIT')
        allow(worker).to receive(:trap).with('INT')
        allow(worker).to receive(:trap).with('TERM').and_yield
        allow(worker).to receive_messages(work_off: [0, 0], stop?: true)
      end

      it 'does not set exit_on_complete' do
        worker.start
        expect(Delayed::Worker.exit_on_complete).to be(false)
      end
    end

    context 'when the worker is processing a named clock queue' do
      before do
        Delayed::Worker.queues = ['app_usage_events']
        allow(worker).to receive(:trap).with('QUIT')
        allow(worker).to receive(:trap).with('INT')
        allow(worker).to receive(:trap).with('TERM').and_yield
        allow(worker).to receive_messages(work_off: [0, 0], stop?: true)
      end

      it 'does not set exit_on_complete' do
        worker.start
        expect(Delayed::Worker.exit_on_complete).to be(false)
      end
    end
  end
end
