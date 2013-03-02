# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"

module VCAP::CloudController
  class DeaPool
    DEA_ADVERTISEMENT_EXPIRATION = 10

    attr_reader :config, :message_bus

    def initialize(config, message_bus)
      @config = config
      @message_bus = message_bus
      @deas = {}
    end

    def register_subscriptions
      message_bus.subscribe("dea.advertise") do |msg|
        process_advertise_message(msg)
      end
    end

    def find_dea(mem, runtime)
      mutex.synchronize do
        deas.keys.shuffle.each do |id|
          dea = lookup_dea_unless_expired(id)
          next unless dea
          return id if dea_meets_needs?(dea, mem, runtime)
        end
        nil
      end
    end

    private

    attr_reader :deas

    def process_advertise_message(msg)
      logger.debug2 "dea advertisement #{msg}"
      refresh_dea_stats(msg[:id], msg)
    end

    def refresh_dea_stats(id, advertisement)
      mutex.synchronize do
        deas[id] = { :advertisement => advertisement,
                     :last_update => Time.now }
      end
    end

    def lookup_dea_unless_expired(id)
      dea = deas[id]
      if Time.now.to_i - dea[:last_update].to_i > DEA_ADVERTISEMENT_EXPIRATION
        deas.delete(id)
        dea = nil
      end
      dea
    end

    def dea_meets_needs?(dea, mem, runtime)
      stats = dea[:advertisement]
      stats[:available_memory] >= mem && (stats[:runtimes].nil? || stats[:runtimes].member?(runtime))
    end

    def mutex
      @mutes ||= Mutex.new
    end

    def logger
      @logger ||= Steno.logger("cc.dea.pool")
    end
  end
end
