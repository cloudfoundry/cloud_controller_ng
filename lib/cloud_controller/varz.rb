# Copyright (c) 2012-2012 VMware, Inc.

require 'steno'

module VCAP::CloudController
  class << self

    def setup_updates
      @timestamp = Time.now
      @current_num_requests = 0
      EM.add_periodic_timer(1) do
        VCAP::CloudController.update_requests_per_sec
      end
    end

    def update_requests_per_sec
      logger = Steno.logger("cc.varz")

      varz = VCAP::Component.varz
      if varz.nil?
        logger.warn("Varz is unavailable.")
      else
        # Update our timestamp and calculate delta for reqs/sec
        now = Time.now
        delta = now - @timestamp
        @timestamp = now
        # Now calculate Requests/sec
        new_num_requests = VCAP::Component.varz[:requests]
        update = ((new_num_requests - @current_num_requests)/delta.to_f).to_i
        varz[:requests_per_sec] = update
        @current_num_requests = new_num_requests
      end
    end

    def setup_varzs
      EM.next_tick do
        varz = VCAP::Component.varz
        varz[:requests] = 0
        varz[:pending_requests] = 0
        varz[:requests_per_sec] = 0

        VCAP::CloudController.setup_updates
      end
    end
  end
end
