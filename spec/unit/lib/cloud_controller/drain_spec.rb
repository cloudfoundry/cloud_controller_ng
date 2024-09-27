require 'spec_helper'
require 'cloud_controller/drain'

module VCAP::CloudController
  RSpec.describe Drain do
    let(:log_dir) { Dir.mktmpdir }

    subject(:drain) { Drain.new(log_dir) }

    def log_contents
      File.open(File.join(log_dir, 'drain', 'drain.log')) do |file|
        yield file.read
      end
    end

    let(:pid) { 23_456 }
    let(:pid_name) { 'pidfile' }
    let(:pid_dir) { Dir.mktmpdir }
    let(:pid_path) { File.join(pid_dir, pid_name) }

    before do
      File.write(pid_path, pid)

      allow(Process).to receive(:kill)

      # Kernel methods must be stubbed on the object instance that uses them
      allow(drain).to receive(:sleep).with(1)
    end

    after do
      FileUtils.rm_r(pid_dir)
      FileUtils.rm_r(log_dir)
    end

    describe '#shutdown_nginx' do
      it 'sends QUIT to the nginx process specified in the pid file' do
        expect(Process).to receive(:kill).with('QUIT', pid)

        drain.shutdown_nginx(pid_path)

        log_contents do |log|
          expect(log).to include("Sending signal 'QUIT' to process '#{pid_name}' with pid '#{pid}'")
        end
      end

      it 'sleeps while it waits for the process to stop' do
        getpgid_returns = [1, 1, nil]
        allow(Process).to receive(:getpgid).with(pid) { getpgid_returns.shift || raise(Errno::ESRCH) }

        drain.shutdown_nginx(pid_path)

        expect(drain).to have_received(:sleep).twice
        log_contents do |log|
          expect(log).to include("Waiting 30s for process '#{pid_name}' with pid '#{pid}' to shutdown")
          expect(log).to include("Waiting 29s for process '#{pid_name}' with pid '#{pid}' to shutdown")
          expect(log).to include("Process '#{pid_name}' with pid '#{pid}' is not running")
        end
      end

      it 'times out after 30 * 1s = 30s (default), sends TERM' do
        getpgid_returns = Array.new(31, 1) + [nil]
        allow(Process).to receive(:getpgid).with(pid) { getpgid_returns.shift || raise(Errno::ESRCH) }
        expect(Process).to receive(:kill).with('QUIT', pid).ordered
        expect(Process).to receive(:kill).with('TERM', pid).ordered

        drain.shutdown_nginx(pid_path)

        expect(drain).to have_received(:sleep).exactly(30).times
      end

      it 'times out after 60 * 1s = 60s if timeout parameter is set to 60, sends TERM' do
        getpgid_returns = Array.new(61, 1) + [nil]
        allow(Process).to receive(:getpgid).with(pid) { getpgid_returns.shift || raise(Errno::ESRCH) }
        expect(Process).to receive(:kill).with('QUIT', pid).ordered
        expect(Process).to receive(:kill).with('TERM', pid).ordered

        drain.shutdown_nginx(pid_path, 60)

        expect(drain).to have_received(:sleep).exactly(60).times
      end

      it 'waits another 10s after sending TERM' do
        allow(Process).to receive(:getpgid).with(pid).and_return(1)

        drain.shutdown_nginx(pid_path)

        expect(drain).to have_received(:sleep).exactly(40).times
        log_contents do |log|
          expect(log).to include("Process '#{pid_name}' with pid '#{pid}' is still running - this indicates an error in the shutdown procedure!")
        end
      end
    end

    describe '#shutdown_cc' do
      it 'sends TERM to the ccng process specified in the pid file' do
        expect(Process).to receive(:kill).with('TERM', pid)

        drain.shutdown_cc(pid_path)

        log_contents do |log|
          expect(log).to match("Sending signal 'TERM' to process '#{pid_name}' with pid '#{pid}'")
        end
      end

      it 'waits 20s after sending TERM' do
        allow(Process).to receive(:getpgid).with(pid).and_return(1)

        drain.shutdown_cc(pid_path)

        expect(drain).to have_received(:sleep).exactly(20).times
        log_contents do |log|
          expect(log).to match("Process '#{pid_name}' with pid '#{pid}' is still running - this indicates an error in the shutdown procedure!")
        end
      end
    end

    describe '#shutdown_delayed_worker' do
      it 'sends TERM to the delayed worker process specified in the pid file' do
        expect(Process).to receive(:kill).with('TERM', pid)

        drain.shutdown_delayed_worker(pid_path)

        log_contents do |log|
          expect(log).to include("Sending signal 'TERM' to process '#{pid_name}' with pid '#{pid}'")
        end
      end

      it 'waits 15s after sending TERM' do
        allow(Process).to receive(:getpgid).with(pid).and_return(1)

        drain.shutdown_delayed_worker(pid_path)

        expect(drain).to have_received(:sleep).exactly(15).times
        log_contents do |log|
          expect(log).to include("Process '#{pid_name}' with pid '#{pid}' is still running - this indicates an error in the shutdown procedure!")
        end
      end

      it 'waits for the given timeout after sending TERM' do
        allow(Process).to receive(:getpgid).with(pid).and_return(1)

        drain.shutdown_delayed_worker(pid_path, 30)

        expect(drain).to have_received(:sleep).exactly(30).times
        log_contents do |log|
          expect(log).to include("Process '#{pid_name}' with pid '#{pid}' is still running - this indicates an error in the shutdown procedure!")
        end
      end

      it 'sends KILL to the delayed worker process if it is still running after 15s' do
        allow(Process).to receive(:getpgid).with(pid).and_return(1)
        allow(Process).to receive(:kill).with('TERM', pid)
        expect(Process).to receive(:kill).with('KILL', pid)

        drain.shutdown_delayed_worker(pid_path)

        log_contents do |log|
          expect(log).to include("Forcefully shutting down process '#{pid_name}' with pid '#{pid}'")
        end
      end
    end
  end
end
