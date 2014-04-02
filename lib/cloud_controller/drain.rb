require "logger"
require "fileutils"

module VCAP
  module CloudController
    class Drain
      def initialize(log_path)
        @log_path = log_path
      end

      def log_invocation(args)
        log_info("Drain invoked with #{args.map{|x| x.inspect}.join(" ")}")
      end

      def unregister_cc(pid_path)
        unregister_wait_timeout = 20 # because we don't know when/wheter the router has acted on the unregister message
        unregister_wait_interval = 5
        send_signal(pid_path, "USR2", "cc_ng")
        while unregister_wait_timeout > 0 do
          log_info("Waiting for router unregister to have taken effect #{unregister_wait_timeout} more seconds")
          sleep unregister_wait_interval
          unregister_wait_timeout -= unregister_wait_interval
        end
      end

      def shutdown_nginx(pid_path)
        nginx_timeout = 30
        nginx_interval = 3
        send_signal(pid_path, "QUIT", "Nginx") # request nginx graceful shutdown
        wait_for_pid(pid_path, nginx_timeout, nginx_interval) # wait until nginx is shut down
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
        if !File.exists?(pidfile)
          log_info("#{program} not running")
          return false
        end
        return true
      end

      def logger
        return @logger if @logger
        log_dir = File.join(@log_path, "drain")
        FileUtils.mkdir_p(log_dir)
        @logger = Logger.new(File.join(log_dir, "drain.log"))
      end
    end
  end
end
