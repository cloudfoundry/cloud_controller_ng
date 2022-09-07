require 'puma'
require 'puma/configuration'

module VCAP::CloudController
  class PumaRunner
    def initialize(config, app, logger, periodic_updater)
      @logger = logger
      @periodic_updater = periodic_updater
    end

    def start!
      puma_config = Puma::Configuration.new do |config|
        config.after_worker_fork {
          Thread.new do
            EM.run do
              @periodic_updater.setup_updates
            end
          end
        }
      end
      @puma_launcher = Puma::Launcher.new(puma_config)
      @puma_launcher.run
    rescue => e
      @logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
      raise e
    end
  end
end
