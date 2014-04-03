require 'spec_helper'
require 'cloud_controller/drain'

module VCAP::CloudController
  describe Drain do
    let(:log_dir) { Dir.mktmpdir }

    subject(:drain) { Drain.new(log_dir) }

    def log_contents
      File.open(File.join(log_dir, "drain", "drain.log")) do |file|
        yield file.read
      end
    end

    let(:pid) { 23456 }
    let(:pid_dir) { Dir.mktmpdir }
    let(:pid_path) { File.join(pid_dir, "pidfile") }

    before do
      File.open(pid_path, "w") do |file|
        file.write(pid)
      end

      # Kernel methods must be stubbed on the object instance that uses them
      allow(drain).to receive(:sleep)
    end

    after do
      FileUtils.rm_r(pid_dir)
      FileUtils.rm_r(log_dir)
    end

    describe "#unregister_cc" do
      before do
        allow(Process).to receive(:kill).with("USR2", pid)
      end

      it "sends USR2 to the process specified in the pid file" do
        drain.unregister_cc(pid_path)

        expect(Process).to have_received(:kill).with("USR2", pid)
      end

      it "sleeps while it waits for the router unregistration" do
        expect(drain).to receive(:sleep).at_least(:once)

        drain.unregister_cc(pid_path)
      end

      it "logs that it sends the signal to CC and is waiting for the router unregistration" do
        drain.unregister_cc(pid_path)

        log_contents do |log|
          expect(log).to match("Sending signal USR2 to cc_ng with pid #{pid}.")
          expect(log).to match("Waiting for router unregister")
        end
      end

      it "logs if the process no longer exists" do
        allow(Process).to receive(:kill).with("USR2", pid).and_raise(Errno::ESRCH)

        drain.unregister_cc(pid_path)

        log_contents do |log|
          expect(log).to match("Pid no longer exists")
        end
      end

      it "logs if the process file no longer exists" do
        allow(File).to receive(:read).with(pid_path).and_raise(Errno::ENOENT)

        drain.unregister_cc(pid_path)

        log_contents do |log|
          expect(log).to match("Pid file no longer exists")
        end
      end
    end

    describe "#shutdown_nginx" do
      before do
        allow(Process).to receive(:kill).with("QUIT", pid)
      end

      it "sends QUIT to the nginx process specified in the pid file" do
        drain.shutdown_nginx(pid_path)
        expect(Process).to have_received(:kill).with("QUIT", pid)

      end

      it "sleeps while it waits for the pid file to be deleted" do
        expect(File).to receive(:exists?).with(pid_path).and_return(true, true, false)
        expect(drain).to receive(:sleep).exactly(2).times

        drain.shutdown_nginx(pid_path)
      end

      it "logs while it waits for the pid file to be deleted" do
        expect(File).to receive(:exists?).with(pid_path).and_return(true, true, false)

        drain.shutdown_nginx(pid_path)

        log_contents do |log|
          expect(log).to match(/Waiting \d+s for \w+ to shutdown/)
        end
      end

      it "logs that the process has stopped running when its pid file is deleted" do
        expect(File).to receive(:exists?).with(pid_path).and_return(true, false)

        drain.shutdown_nginx(pid_path)

        log_contents do |log|
          expect(log).to match(/\w+ not running/)
        end
      end

    end

    describe "#log_invocation" do
      it "logs that the drain is invoked with the given arguments" do
        drain.log_invocation([1, "banana"])

        log_contents do |log|
          expect(log).to match(/Drain invoked with.*1.*banana/)
        end
      end
    end
  end
end
