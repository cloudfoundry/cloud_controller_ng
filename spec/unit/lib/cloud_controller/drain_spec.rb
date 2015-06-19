require 'spec_helper'
require 'cloud_controller/drain'

module VCAP::CloudController
  describe Drain do
    let(:log_dir) { Dir.mktmpdir }

    subject(:drain) { Drain.new(log_dir) }

    def log_contents
      File.open(File.join(log_dir, 'drain', 'drain.log')) do |file|
        yield file.read
      end
    end

    let(:pid) { 23456 }
    let(:pid_dir) { Dir.mktmpdir }
    let(:pid_path) { File.join(pid_dir, 'pidfile') }

    before do
      File.open(pid_path, 'w') do |file|
        file.write(pid)
      end

      # Kernel methods must be stubbed on the object instance that uses them
      allow(drain).to receive(:sleep)
    end

    after do
      FileUtils.rm_r(pid_dir)
      FileUtils.rm_r(log_dir)
    end

    describe '#shutdown_nginx' do
      before do
        allow(Process).to receive(:kill).with('QUIT', pid)
      end

      it 'sends QUIT to the nginx process specified in the pid file' do
        drain.shutdown_nginx(pid_path)
        expect(Process).to have_received(:kill).with('QUIT', pid)
      end

      it 'sleeps while it waits for the pid file to be deleted' do
        expect(File).to receive(:exist?).with(pid_path).and_return(true, true, false)
        expect(drain).to receive(:sleep).exactly(2).times

        drain.shutdown_nginx(pid_path)
      end

      it 'logs while it waits for the pid file to be deleted' do
        expect(File).to receive(:exist?).with(pid_path).and_return(true, true, false)

        drain.shutdown_nginx(pid_path)

        log_contents do |log|
          expect(log).to match(/Waiting \d+s for \w+ to shutdown/)
        end
      end

      it 'logs that the process has stopped running when its pid file is deleted' do
        expect(File).to receive(:exist?).with(pid_path).and_return(true, false)

        drain.shutdown_nginx(pid_path)

        log_contents do |log|
          expect(log).to match(/\w+ not running/)
        end
      end
    end

    describe '#shutdown_cc' do
      before do
        allow(Process).to receive(:kill).with('TERM', pid)
      end

      it 'sends TERM to the cc process specified in the pid file' do
        drain.shutdown_cc(pid_path)
        expect(Process).to have_received(:kill).with('TERM', pid)
      end
    end

    describe '#log_invocation' do
      it 'logs that the drain is invoked with the given arguments' do
        drain.log_invocation([1, 'banana'])

        log_contents do |log|
          expect(log).to match(/Drain invoked with.*1.*banana/)
        end
      end
    end
  end
end
