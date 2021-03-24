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

      def shutdown_nginx(pid_path, timeout=30)
        nginx_timeout = timeout
        nginx_interval = 1
        pid = File.read(pid_path).to_i
        process_name = File.basename(pid_path)
        send_signal(pid, 'QUIT', 'Nginx') # request nginx graceful shutdown
        wait_for_pid(pid, process_name, nginx_timeout, nginx_interval) # wait until nginx is shut down
        if alive?(pid, process_name)
          send_signal(pid, 'TERM', 'Nginx') # nginx force shutdown
        end
      end

      def shutdown_cc(pid_path)
        pid = File.read(pid_path).to_i
        send_signal(pid, 'TERM', 'cc_ng')
      end

      private

      def send_signal(pid, signal, program)
        log_info("Sending signal #{signal} to #{program} with pid #{pid}.")
        Process.kill(signal, pid)
      rescue Errno::ESRCH => e
        log_info("#{program} not running: Pid no longer exists: #{e}")
      rescue Errno::ENOENT => e
        log_info("#{program} not running: Pid file no longer exists: #{e}")
      end

      def wait_for_pid(pid, process_name, timeout, interval)
        while alive?(pid, process_name) && timeout > 0
          log_info("Waiting #{timeout}s for #{process_name} to shutdown")
          sleep(interval)
          timeout -= interval
        end
      end

      def log_info(message)
        logger.info("cc.drain: #{message}")
      end

      def alive?(pid, process_name)
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        log_info("#{process_name} with pid '#{pid}' not running")
        false
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
