require 'spec_helper'
require 'delayed_job'
require 'delayed_job/threaded_worker'
require 'delayed_job/plugin_threaded_worker_patch'

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
        sleep 0.1 until queue.size == 1

        expect(exec_counter).to eq(1)
        expect(loop_counter).to eq(1)
      end

      it 'calls the clear_locks plugin' do
        clear_locks_queue = Queue.new
        allow(Delayed::Backend::Sequel::Job).to receive(:clear_locks!) do |_|
          clear_locks_queue.push(:clear_locks_called)
        end

        worker = worker_class.new(worker_options)
        worker.name = worker_name

        work_off_queue = Queue.new
        allow(worker).to receive(:work_off) do
          work_off_queue.push(:work_off_called)
          [0, 0]
        end
        Thread.new { worker.start }
        sleep 0.1 until work_off_queue.size == 1
        worker.stop

        counter = 0
        until clear_locks_queue.size == 1 || (counter += 1) > 5
          sleep 0.1
        end
        expect(counter).to be <= 5 # If higher clear_locks! was not called

        expect(Delayed::Backend::Sequel::Job).to have_received(:clear_locks!).with(expected_worker_name_in_cleanup)
      end
    end
  end

  describe Delayed::ThreadedWorker do
    it_behaves_like 'a worker with plugins', Delayed::ThreadedWorker, { num_threads: 1, sleep_delay: 0.2, grace_period_seconds: 2 }, 'instance_name',
                    'instance_name thread:1'
  end

  describe Delayed::Worker do
    it_behaves_like 'a worker with plugins', Delayed::Worker, { sleep_delay: 0.2 }, 'instance_name', 'instance_name'
  end
end
