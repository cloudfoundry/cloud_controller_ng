require 'clockwork'

module VCAP::CloudController
  class Clock
    def initialize(config)
      @config = config
      @logger = Steno.logger('cc.clock')
    end

    def schedule_cleanup(name, klass, at)
      config = @config.fetch(name.to_sym)

      Clockwork.every(1.day, "#{name}.cleanup.job", at: at) do |_|
        @logger.info("Queueing #{klass} at #{Time.now.utc}")
        cutoff_age_in_days = config.fetch(:cutoff_age_in_days)
        job                = klass.new(cutoff_age_in_days)
        Jobs::Enqueuer.new(job, queue: 'cc-generic').enqueue
      end
    end

    def schedule_frequent_cleanup(name, klass)
      config = @config.fetch(name.to_sym)

      Clockwork.every(config.fetch(:frequency_in_seconds), "#{name}.cleanup.job") do |_|
        @logger.info("Queueing #{klass} at #{Time.now.utc}")
        expiration = config.fetch(:expiration_in_seconds)
        job        = klass.new(expiration)
        Jobs::Enqueuer.new(job, queue: 'cc-generic').enqueue
      end
    end
  end
end
