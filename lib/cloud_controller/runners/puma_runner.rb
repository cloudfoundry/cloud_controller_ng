require 'puma'
require 'puma/configuration'

module VCAP::CloudController
  class PumaRunner
    def initialize(config, app, logger, periodic_updater, request_logs)
      @logger = logger
      @periodic_updater = periodic_updater
      @request_logs = request_logs
      puma_config = Puma::Configuration.new do |conf|
        conf.after_worker_fork {
          Thread.new do
            EM.run do
              @periodic_updater.setup_updates
            end
          end
        }
      end
      @puma_launcher = Puma::Launcher.new(puma_config)
      @puma_launcher.events.on_stopped do
        stop!
      end
    end

    def start!
      @puma_launcher.run
    rescue => e
      @logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
      raise e
    end

    def stop!
      @logger.info('Stopping EventMachine')
      EM.stop
      @request_logs.log_incomplete_requests if @request_logs
    end
  end
end
