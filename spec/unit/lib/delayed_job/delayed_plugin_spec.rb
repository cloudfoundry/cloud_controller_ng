require 'spec_helper'
require 'delayed_job'
require 'delayed_job/threaded_worker'

RSpec.describe 'plugin_threaded_worker_patch' do
  RSpec.shared_examples 'a worker with plugins' do |worker_class, worker_options, worker_name, expected_worker_name_in_cleanup|
    describe 'plugins' do
      it 'calls the plugin lifecycle callbacks' do
        exec_counter = 0
        exec_plugin = Class.new(Delayed::Plugin) { callbacks { |lifecycle| lifecycle.before(:execute) { exec_counter += 1 } } }

        loop_counter = 0
        loop_plugin = Class.new(Delayed::Plugin) { callbacks { |lifecycle| lifecycle.before(:loop) { loop_counter += 1 } } }

        worker_class.plugins << exec_plugin
        worker_class.plugins << loop_plugin

        worker = worker_class.new(worker_options)
        allow(worker).to receive(:work_off).and_return([0, 0])

        queue = Queue.new
        allow(worker).to receive(:work_off) do
          queue.push(:work_off_called)
          [0, 0]
        end
        Thread.new { worker.start }
        work_counter = 0
        sleep 0.3 until queue.size == 1 || (work_counter += 1) > 10
        expect(work_counter).to be <= 10 # If higher work_off was not called

        expect(exec_counter).to eq(1)
        expect(loop_counter).to eq(1)
      end

      it 'calls the clear_locks plugin' do
        clear_locks_queue = Queue.new
        allow(Delayed::Backend::Sequel::Job).to(receive(:clear_locks!)) { |_| clear_locks_queue.push(:clear_locks_called) }

        worker = worker_class.new(worker_options)
        worker.name = worker_name

        work_off_queue = Queue.new
        allow(worker).to receive(:work_off) do
          work_off_queue.push(:work_off_called)
          [0, 0]
        end
        Thread.new { worker.start }
        work_counter = 0
        sleep 0.3 until work_off_queue.size == 1 || (work_counter += 1) > 10
        expect(work_counter).to be <= 10 # If higher work_off was not called

        worker.stop

        clear_counter = 0
        sleep 0.3 until clear_locks_queue.size == 1 || (clear_counter += 1) > 10

        expect(clear_counter).to be <= 10 # If higher clear_locks! was not called

        expect(Delayed::Backend::Sequel::Job).to have_received(:clear_locks!).with(expected_worker_name_in_cleanup)
      end
    end
  end

  describe Delayed::ThreadedWorker do
    original_worker = Delayed::Worker

    before do
      Delayed.module_eval do
        remove_const(:Worker)
        const_set(:Worker, Delayed::ThreadedWorker)
      end
    end

    after do
      Delayed.module_eval do
        remove_const(:Worker)
        const_set(:Worker, original_worker)
      end
    end

    it_behaves_like 'a worker with plugins', Delayed::ThreadedWorker, { num_threads: 1, sleep_delay: 0.2, grace_period_seconds: 2 }, 'instance_name',
                    'instance_name thread:1'
  end

  describe Delayed::Worker do
    it_behaves_like 'a worker with plugins', Delayed::Worker, { sleep_delay: 0.2 }, 'instance_name', 'instance_name'
  end
end
