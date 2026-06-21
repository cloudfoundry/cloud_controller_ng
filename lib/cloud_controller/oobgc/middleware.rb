# oobgc:
#   start_threshold_mb: 250
#   critical_threshold_mb: 500
#   opt_in_paths:
#     - "/v3/droplets"
#     - "/v3/packages"
# async_gc:
#   max_concurrent_deletes: 5
#   db_thread_pool_size: 5
#   blob_delete_timeout_seconds: 10

module VCAP::CloudController
  module Oobgc
    class Middleware
      def initialize(app, config)
        @app = app
        @config = config
      end

      def call(env)
        req = Rack::Request.new(env)
        opt_in_paths = @config.dig(:oobgc, :opt_in_paths) || []
        
        if opt_in_paths.any? { |p| req.path.start_with?(p) }
          start_threshold_kb = (@config.dig(:oobgc, :start_threshold_mb) || 250) * 1024
          critical_threshold_kb = (@config.dig(:oobgc, :critical_threshold_mb) || 500) * 1024
          
          current_rss = read_rss_kb

          if current_rss && current_rss < start_threshold_kb
            # Activate OOBGC for this request
            env['oobgc.active'] = true
            env['oobgc.critical_threshold'] = critical_threshold_kb
            env['oobgc.gc_enabled'] = false
            Thread.current[:rack_env] = env
            
            GC.disable
            
            # Spawn monitor thread
            monitor_thread = spawn_monitor_thread(env)
            env['oobgc.monitor_thread'] = monitor_thread
          end
        end

        status, headers, body = @app.call(env)

        if env['oobgc.active']
          # Hook into the response close to trigger the cleanup
          if body.respond_to?(:close)
            # Monkey-patch close or use Rack::BodyProxy
            body_proxy = Rack::BodyProxy.new(body) do
              cleanup(env)
            end
            [status, headers, body_proxy]
          else
            # If body doesn't respond to close, cleanup immediately
            cleanup(env)
            [status, headers, body]
          end
        else
          [status, headers, body]
        end
      end

      private

      def read_rss_kb
        # Read from /proc/self/status for VmRSS
        status_file = "/proc/#{Process.pid}/status"
        return nil unless File.exist?(status_file)

        File.read(status_file).each_line do |line|
          if line.start_with?('VmRSS:')
            # e.g. "VmRSS:     50000 kB"
            return line.split[1].to_i
          end
        end
        nil
      rescue StandardError
        nil
      end

      def spawn_monitor_thread(env)
        Thread.new do
          monitor_interval_seconds = @config.dig(:oobgc, :monitor_interval_seconds) || 1.0
          
          while env['oobgc.active']
            sleep(monitor_interval_seconds)
            
            # Re-check to ensure it hasn't been deactivated during sleep
            break unless env['oobgc.active']

            current_rss = read_rss_kb
            next unless current_rss
            
            if current_rss >= env['oobgc.critical_threshold'] && !env['oobgc.gc_enabled']
              env['oobgc.gc_enabled'] = true
              GC.enable
              GC.start(full_mark: true, immediate_sweep: false)
              
              if defined?(Statsd) && Statsd.logger
                Statsd.logger.increment('oobgc.midflight.monitor_thread_triggered')
              end
              break
            end
          end
        end
      end

      def cleanup(env)
        # Terminate monitor thread
        env['oobgc.active'] = nil
        if env['oobgc.monitor_thread']
          env['oobgc.monitor_thread'].kill if env['oobgc.monitor_thread'].alive?
        end

        # Run appropriate GC cycle
        if env['oobgc.gc_enabled'] == false
          GC.enable # We must re-enable before starting
          GC.start
        else
          GC.compact
        end

        # Clean up global thread state
        Thread.current[:rack_env] = nil
      end
    end
  end
end
