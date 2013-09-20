# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"
require "cloud_controller/stager/stager_advertisment"

module VCAP::CloudController
  class StagerPool
    attr_reader :config, :message_bus

    def initialize(config, message_bus)
      @config = config
      @message_bus = message_bus
      @stager_advertisements = []
    end

    def register_subscriptions
      message_bus.subscribe("staging.advertise") do |msg|
        process_advertise_message(msg)
      end
    end

    def process_advertise_message(msg)
      mutex.synchronize do
        advertisement = StagerAdvertisement.new(msg)

        remove_advertisement_for_id(advertisement.stager_id)
        @stager_advertisements << advertisement
      end
    end

    def find_stager(stack, memory)
      mutex.synchronize do
        validate_stack_availability(stack)

        prune_stale_advertisements
        eligible_ads = @stager_advertisements.select { |ad| ad.meets_needs?(memory, stack) }
        best_ad = eligible_ads.sample # preserving old behavior of picking a random stager
        best_ad && best_ad.stager_id
      end
    end

    def validate_stack_availability(stack)
      unless @stager_advertisements.any? { |ad| ad.has_stack?(stack) }
        raise Errors::StackNotFound, "The requested app stack #{stack} is not available on this system."
      end
    end

    private
    def prune_stale_advertisements
      @stager_advertisements.delete_if { |ad| ad.expired? }
    end

    def remove_advertisement_for_id(id)
      @stager_advertisements.delete_if { |ad| ad.stager_id == id }
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
