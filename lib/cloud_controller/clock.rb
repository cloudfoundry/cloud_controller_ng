require "clockwork"

module VCAP::CloudController
  module Clock
    def self.start
      logger = Steno.logger("cc.clock")
      Clockwork.every(10.minutes, "dummy.scheduled.job") do |job|
        logger.info("Would have run #{job}")
      end

      Clockwork.run
    end
  end
end
