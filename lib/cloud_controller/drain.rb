require 'logger'
require 'fileutils'

module VCAP
  module CloudController
    class Drain
      def initialize(log_path)
        @log_path = log_path
      end

      def log_invocation(args)
        log_info("Drain invoked with #{args.map(&:inspect).join(' ')}")
      end

      def shutdown_nginx(pid_path)
        nginx_timeout = 30
        nginx_interval = 3
        send_signal(pid_path, 'QUIT', 'Nginx') # request nginx graceful shutdown
        wait_for_pid(pid_path, nginx_timeout, nginx_interval) # wait until nginx is shut down
      end

      def shutdown_cc(pid_path)
        send_signal(pid_path, 'TERM', 'cc_ng')
      end

      private

      def send_signal(pidfile, signal, program)
        pid = File.read(pidfile).to_i
        log_info("Sending signal #{signal} to #{program} with pid #{pid}.")
        Process.kill(signal, pid)
      rescue Errno::ESRCH => e
        log_info("#{program} not running: Pid no longer exists: #{e}")
      rescue Errno::ENOENT => e
        log_info("#{program} not running: Pid file no longer exists: #{e}")
      end

      def wait_for_pid(pidfile, timeout, interval)
        process_name = File.basename(pidfile)
        while alive?(pidfile, process_name) && timeout > 0
          log_info("Waiting #{timeout}s for #{process_name} to shutdown")
          sleep(interval)
          timeout -= interval
        end
      end

      def log_info(message)
        logger.info("cc.drain: #{message}")
      end

      def alive?(pidfile, program)
        if !File.exist?(pidfile)
          log_info("#{program} not running")
          return false
        end
        true
      end

      def logger
        return @logger if @logger
        log_dir = File.join(@log_path, 'drain')
        FileUtils.mkdir_p(log_dir)
        @logger = Logger.new(File.join(log_dir, 'drain.log'))
      end
    end
  end
end
