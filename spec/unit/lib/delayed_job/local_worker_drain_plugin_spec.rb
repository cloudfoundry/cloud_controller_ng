require 'spec_helper'
require 'delayed_job/local_worker_drain_plugin'

RSpec.describe LocalWorkerDrainPlugin do
  let(:worker) { Delayed::Worker.new }

  before do
    Delayed::Worker.exit_on_complete = false
    allow(worker).to receive(:reload!)
    allow(worker).to receive(:say)
  end

  after do
    Delayed::Worker.exit_on_complete = false
    Delayed::Worker.plugins.delete(LocalWorkerDrainPlugin)
  end

  describe 'TERM signal handling' do
    before do
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
end
