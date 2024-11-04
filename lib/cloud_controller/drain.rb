# This class is used in capi-release (e.g. https://github.com/cloudfoundry/capi-release/blob/b817791b0f4d8780304cef148f1aeb3f2a944af8/jobs/cloud_controller_ng/templates/shutdown_drain.rb.erb#L8)

require 'logger'
require 'fileutils'

module VCAP
  module CloudController
    class Drain
      NGINX_FINAL_TIMEOUT = 10
      CCNG_FINAL_TIMEOUT = 20
      SLEEP_INTERVAL = 1

      def initialize(log_path)
        @log_path = log_path
      end

      def shutdown_nginx(pid_path, timeout=30)
        pid = File.read(pid_path).to_i
        process_name = File.basename(pid_path, '.pid')

        # Initiate graceful shutdown.
        send_signal('QUIT', pid, process_name)
        return if wait_for_shutdown(pid, process_name, timeout)

        # Graceful shutdown did not succeed, initiate forceful shutdown.
        send_signal('TERM', pid, process_name)

        # Wait some additional time for nginx to be terminated; otherwise write an error log message.
        log_shutdown_error(pid, process_name) unless wait_for_shutdown(pid, process_name, NGINX_FINAL_TIMEOUT)
      end

      def shutdown_cc(pid_path)
        pid = File.read(pid_path).to_i
        process_name = File.basename(pid_path, '.pid')

        # Initiate shutdown.
        send_signal('TERM', pid, process_name)

        # Wait some additional time for cloud controller to be terminated; otherwise write an error log message.
        log_shutdown_error(pid, process_name) unless wait_for_shutdown(pid, process_name, CCNG_FINAL_TIMEOUT)
      end

      def shutdown_delayed_worker(pid_path, timeout=15)
        pid = File.read(pid_path).to_i
        process_name = File.basename(pid_path, '.pid')

        # Initiate shutdown.
        send_signal('TERM', pid, process_name)

        # Wait some additional time for delayed worker to be terminated; otherwise write an error log message.
        log_shutdown_error(pid, process_name) unless wait_for_shutdown(pid, process_name, timeout)

        # force shutdown
        return if terminated?(pid, process_name)

        log_info("Forcefully shutting down process '#{process_name}' with pid '#{pid}'")
        send_signal('KILL', pid, process_name)
      end

      private

      def send_signal(signal, pid, process_name)
        log_info("Sending signal '#{signal}' to process '#{process_name}' with pid '#{pid}'")
        Process.kill(signal, pid)
      rescue Errno::ESRCH => e
        log_info("Process '#{process_name}' is not running: Pid no longer exists: #{e}")
      rescue Errno::ENOENT => e
        log_info("Process '#{process_name}' is not running: Pid file no longer exists: #{e}")
      end

      def wait_for_shutdown(pid, process_name, timeout)
        terminated = terminated?(pid, process_name)
        while !terminated && timeout > 0
          log_info("Waiting #{timeout}s for process '#{process_name}' with pid '#{pid}' to shutdown")
          sleep(SLEEP_INTERVAL)
          timeout -= SLEEP_INTERVAL
          terminated = terminated?(pid, process_name)
        end
        terminated
      end

      def terminated?(pid, process_name)
        Process.getpgid(pid)
        false
      rescue Errno::ESRCH
        log_info("Process '#{process_name}' with pid '#{pid}' is not running")
        true
      end

      def log_info(message)
        logger.info("cc.drain: #{message}")
      end

      def log_shutdown_error(pid, process_name)
        message = "Process '#{process_name}' with pid '#{pid}' is still running - this indicates an error in the shutdown procedure!"
        logger.error("cc.drain: #{message}")
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
