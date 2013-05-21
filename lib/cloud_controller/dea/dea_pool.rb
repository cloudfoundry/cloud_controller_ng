# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"

module VCAP::CloudController
  class DeaPool
    ADVERTISEMENT_EXPIRATION = 10.freeze

    attr_reader :config, :message_bus

    def initialize(config, message_bus)
      @config = config
      @message_bus = message_bus
      @dea_advertisements = []
    end

    def register_subscriptions
      message_bus.subscribe("dea.advertise") do |msg|
        process_advertise_message(msg)
      end
    end

    def process_advertise_message(message)
      mutex.synchronize do
        advertisement = DeaAdvertisement.new(message, Time.now)

        # remove older advertisements for the same dea_id
        @dea_advertisements.delete_if { |ad| ad.dea_id == advertisement.dea_id }
        @dea_advertisements << advertisement
      end
    end

    def find_dea(mem, stack, app_id)
      mutex.synchronize do
        prune_stale_deas
        eligible_ads = @dea_advertisements.select { |ad| dea_meets_needs?(ad, mem, stack) }
        best_dea_ad = eligible_ads.min_by { |ad| ad.num_instances_of(app_id) }
        best_dea_ad && best_dea_ad.dea_id
      end
    end

    def mark_app_staged(opts)
      dea_id = opts[:dea_id]
      app_id = opts[:app_id]

      @dea_advertisements.find { |ad| ad.dea_id == dea_id }.increment_instance_count(app_id)
    end

    private

    def prune_stale_deas
      @dea_advertisements.delete_if { |ad| advertisement_expired?(ad) }
    end

    def advertisement_expired?(ad)
      (Time.now.to_i - ad.last_update.to_i) > ADVERTISEMENT_EXPIRATION
    end

    def dea_meets_needs?(advertisement, mem, stack)
      advertisement.has_sufficient_memory?(mem) && advertisement.has_stack?(stack)
    end

    def mutex
      @mutex ||= Mutex.new
    end

    class DeaAdvertisement
      attr_reader :stats, :last_update

      def initialize(stats, last_update)
        @stats = stats
        @last_update = last_update
      end

      def increment_instance_count(app_id)
        stats[:app_id_to_count][app_id] = num_instances_of(app_id) + 1
      end

      def num_instances_of(app_id)
        stats[:app_id_to_count].fetch(app_id, 0)
      end

      def dea_id
        stats[:id]
      end

      def has_stack?(stack)
        stats[:stacks].include?(stack)
      end

      def has_sufficient_memory?(mem)
        stats[:available_memory] >= mem
      end
    end
  end
end
