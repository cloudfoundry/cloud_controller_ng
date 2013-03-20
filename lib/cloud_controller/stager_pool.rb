# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"

module VCAP::CloudController
  class StagerPool
    ADVERTISEMENT_EXPIRATION = 10

    attr_reader :config, :message_bus

    def initialize(config, message_bus)
      @config = config
      @message_bus = message_bus
      @stagers = {}
    end

    def register_subscriptions
      message_bus.subscribe("staging.advertise") do |msg|
        process_advertise_message(msg)
      end
    end

    def process_advertise_message(msg)
      mutex.synchronize do
        @stagers[msg[:id]] = {
          :advertisement => msg,
          :last_update => Time.now,
        }
      end
    end

    def find_stager(stack, memory)
      mutex.synchronize do
        validate_stack_availability(stack)
        @stagers.keys.shuffle.each do |id|
          stager = @stagers[id]
          if stager_expired?(stager)
            @stagers.delete(id)
          elsif stager_meets_needs?(stager, memory, stack)
            return id
          end
        end
        nil
      end
    end

    def validate_stack_availability(stack)
      unless @stagers.find { |_, stager| stager[:advertisement][:stacks].include?(stack) }
        raise Errors::StackNotFound, "The requested app stack #{stack} is not available on this system."
      end
    end

    private

    def stager_expired?(stager)
      (Time.now.to_i - stager[:last_update].to_i) > ADVERTISEMENT_EXPIRATION
    end

    def stager_meets_needs?(stager, mem, stack)
      stats = stager[:advertisement]
      if stats[:available_memory] >= mem
        stats[:stacks].include?(stack)
      else
        false
      end
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
